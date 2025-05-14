;; DeFiInsight Platform - Enhanced Implementation
;; Version 2.0.0

;; Primary Constants
(define-constant admin-account tx-sender)
(define-constant ERR-PERMISSION-DENIED (err u4001))
(define-constant ERR-CHAIN-UNSUPPORTED (err u4002))
(define-constant ERR-QUANTITY-INVALID (err u4003))
(define-constant ERR-STX-BALANCE-LOW (err u4004))
(define-constant ERR-WAITING-PERIOD (err u4005))
(define-constant ERR-NO-PARTICIPATION (err u4006))
(define-constant ERR-THRESHOLD-UNMET (err u4007))
(define-constant ERR-SYSTEM-SUSPENDED (err u4008))

;; Platform Token Definition
(define-fungible-token INSIGHT-TOKEN)

;; System Status Variables
(define-data-var system-suspended bool false)
(define-data-var crisis-mode bool false)

;; Participation Parameters
(define-data-var stx-reserve uint u0)
(define-data-var default-yield uint u500) ;; 5% standard rate (100 = 1%)
(define-data-var duration-incentive uint u100) ;; 1% bonus for longer participation
(define-data-var entry-threshold uint u1000000) ;; Minimum participation amount
(define-data-var cooldown-duration uint u1440) ;; 24 hour waiting period in blocks

;; Enhanced Data Structures
(define-map ParticipantMetrics
    principal
    {
        stx-committed: uint,
        platform-tokens: uint,
        latest-activity: uint,
        membership-level: uint,
        yield-booster: uint,
        stability-index: uint
    }
)

(define-map CommitmentDetails
    principal
    {
        quantity: uint,
        entry-block: uint,
        recent-collection: uint,
        lock-duration: uint,
        exit-timer: (optional uint),
        pending-rewards: uint
    }
)

(define-map MembershipTiers
    uint  ;; membership level
    {
        threshold-requirement: uint,
        tier-booster: uint,
        capability-access: (list 2 bool)
    }
)

;; Platform Initialization
(define-public (setup-platform)
    (begin
        (asserts! (is-eq tx-sender admin-account) ERR-PERMISSION-DENIED)
        
        ;; Configure membership tiers
        (map-set MembershipTiers u1 
            {
                threshold-requirement: u1000000,  ;; 1M uSTX
                tier-booster: u100,     ;; 1x
                capability-access: (list true false)
            })
        (map-set MembershipTiers u2
            {
                threshold-requirement: u5000000,  ;; 5M uSTX
                tier-booster: u150,     ;; 1.5x
                capability-access: (list true true)
            })
        (map-set MembershipTiers u3
            {
                threshold-requirement: u10000000, ;; 10M uSTX
                tier-booster: u200,     ;; 2x
                capability-access: (list true true)
            })
        
        (ok true)
    )
)

;; Commit STX with optional time lock
(define-public (commit-stx (quantity uint) (lock-period uint))
    (let
        (
            (current-metrics (default-to 
                {
                    stx-committed: u0,
                    platform-tokens: u0,
                    latest-activity: u0,
                    membership-level: u0,
                    yield-booster: u100,
                    stability-index: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
        )
        (asserts! (not (var-get system-suspended)) ERR-SYSTEM-SUSPENDED)
        (asserts! (>= quantity (var-get entry-threshold)) ERR-THRESHOLD-UNMET)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? quantity tx-sender (as-contract tx-sender)))
        
        ;; Calculate tier and multiplier
        (let
            (
                (new-total-commitment (+ (get stx-committed current-metrics) quantity))
                (membership-info (evaluate-membership-level new-total-commitment))
                (period-bonus (calculate-period-bonus lock-period))
                (stability-computation (calculate-stability-index new-total-commitment))
            )
            
            ;; Update commitment details
            (map-set CommitmentDetails
                tx-sender
                {
                    quantity: quantity,
                    entry-block: block-height,
                    recent-collection: block-height,
                    lock-duration: lock-period,
                    exit-timer: none,
                    pending-rewards: u0
                }
            )
            
            ;; Update participant metrics with new tier data
            (map-set ParticipantMetrics
                tx-sender
                (merge current-metrics
                    {
                        stx-committed: new-total-commitment,
                        stability-index: stability-computation,
                        membership-level: membership-info,
                        yield-booster: (* (tier-bonus membership-info) period-bonus),
                        latest-activity: block-height
                    }
                )
            )
            
            ;; Update STX reserve
            (var-set stx-reserve (+ (var-get stx-reserve) quantity))
            (ok true)
        )
    )
)

;; Initiate exit process
(define-public (request-exit (quantity uint))
    (let
        (
            (current-metrics (default-to 
                {
                    stx-committed: u0,
                    platform-tokens: u0,
                    latest-activity: u0,
                    membership-level: u0,
                    yield-booster: u100,
                    stability-index: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
            (commitment-info (default-to
                {
                    quantity: u0,
                    entry-block: u0,
                    recent-collection: u0,
                    lock-duration: u0,
                    exit-timer: none,
                    pending-rewards: u0
                }
                (map-get? CommitmentDetails tx-sender)))
            (current-committed (get stx-committed current-metrics))
            (active-lockperiod (get lock-duration commitment-info))
        )
        (asserts! (not (var-get system-suspended)) ERR-SYSTEM-SUSPENDED)
        (asserts! (<= quantity current-committed) ERR-STX-BALANCE-LOW)
        
        ;; Check if lock period is over
        (asserts! (<= active-lockperiod block-height) ERR-WAITING-PERIOD)
        
        ;; Set exit timer
        (map-set CommitmentDetails
            tx-sender
            (merge commitment-info
                {
                    exit-timer: (some block-height)
                }
            )
        )
        
        (ok block-height)
    )
)

;; Complete exit after cooldown period
(define-public (complete-exit (quantity uint))
    (let
        (
            (current-metrics (default-to 
                {
                    stx-committed: u0,
                    platform-tokens: u0,
                    latest-activity: u0,
                    membership-level: u0,
                    yield-booster: u100,
                    stability-index: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
            (commitment-info (default-to
                {
                    quantity: u0,
                    entry-block: u0,
                    recent-collection: u0,
                    lock-duration: u0,
                    exit-timer: none,
                    pending-rewards: u0
                }
                (map-get? CommitmentDetails tx-sender)))
            (current-committed (get stx-committed current-metrics))
            (exit-timestamp (get exit-timer commitment-info))
        )
        (asserts! (not (var-get system-suspended)) ERR-SYSTEM-SUSPENDED)
        (asserts! (<= quantity current-committed) ERR-STX-BALANCE-LOW)
        (asserts! (is-some exit-timestamp) ERR-NO-PARTICIPATION)
        
        ;; Check if cooldown period is over
        (asserts! (>= block-height (+ (default-to u0 exit-timestamp) (var-get cooldown-duration))) ERR-WAITING-PERIOD)
        
        ;; Transfer STX from contract
        (try! (as-contract (stx-transfer? quantity tx-sender tx-sender)))
        
        ;; Calculate new tier after withdrawal
        (let
            (
                (new-total-commitment (- current-committed quantity))
                (membership-info (evaluate-membership-level new-total-commitment))
                (stability-computation (calculate-stability-index new-total-commitment))
            )
            
            ;; Update participant metrics with new tier data
            (map-set ParticipantMetrics
                tx-sender
                (merge current-metrics
                    {
                        stx-committed: new-total-commitment,
                        stability-index: stability-computation,
                        membership-level: membership-info,
                        yield-booster: (tier-bonus membership-info),
                        latest-activity: block-height
                    }
                )
            )
            
            ;; Reset exit timer
            (map-set CommitmentDetails
                tx-sender
                (merge commitment-info
                    {
                        exit-timer: none
                    }
                )
            )
            
            ;; Update STX reserve
            (var-set stx-reserve (- (var-get stx-reserve) quantity))
            (ok true)
        )
    )
)

;; Collect rewards based on commitment
(define-public (collect-rewards)
    (let
        (
            (current-metrics (default-to 
                {
                    stx-committed: u0,
                    platform-tokens: u0,
                    latest-activity: u0,
                    membership-level: u0,
                    yield-booster: u100,
                    stability-index: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
            (commitment-info (default-to
                {
                    quantity: u0,
                    entry-block: u0,
                    recent-collection: u0,
                    lock-duration: u0,
                    exit-timer: none,
                    pending-rewards: u0
                }
                (map-get? CommitmentDetails tx-sender)))
            (blocks-passed (- block-height (get recent-collection commitment-info)))
            (committed-amount (get stx-committed current-metrics))
            (yield-booster (get yield-booster current-metrics))
            (uncollected (get pending-rewards commitment-info))
        )
        (asserts! (> committed-amount u0) ERR-STX-BALANCE-LOW)
        
        ;; Calculate rewards
        (let
            (
                (standard-yield (/ (* committed-amount blocks-passed (var-get default-yield)) u1000000))
                (boosted-yield (/ (* standard-yield yield-booster) u100))
                (total-yield (+ boosted-yield uncollected))
            )
            
            ;; Mint reward tokens
            (try! (ft-mint? INSIGHT-TOKEN total-yield tx-sender))
            
            ;; Update commitment details
            (map-set CommitmentDetails
                tx-sender
                (merge commitment-info
                    {
                        recent-collection: block-height,
                        pending-rewards: u0
                    }
                )
            )
            
            ;; Update participant metrics
            (map-set ParticipantMetrics
                tx-sender
                (merge current-metrics
                    {
                        platform-tokens: (+ (get platform-tokens current-metrics) total-yield),
                        latest-activity: block-height
                    }
                )
            )
            
            (ok total-yield)
        )
    )
)

;; Helper Functions

;; Determine membership level based on commitment amount
(define-private (evaluate-membership-level (commitment-amount uint))
    (if (>= commitment-amount u10000000)
        u3
        (if (>= commitment-amount u5000000)
            u2
            u1
        )
    )
)

;; Get tier bonus
(define-private (tier-bonus (tier uint))
    (if (is-eq tier u3)
        u200
        (if (is-eq tier u2)
            u150
            u100
        )
    )
)

;; Calculate period bonus based on lock duration
(define-private (calculate-period-bonus (lock-period uint))
    (if (>= lock-period u8640)     ;; 2 months
        u150                        ;; 1.5x multiplier
        (if (>= lock-period u4320) ;; 1 month
            u125                    ;; 1.25x multiplier
            u100                    ;; 1x multiplier (no lock)
        )
    )
)

;; Calculate stability index
(define-private (calculate-stability-index (assets uint))
    (if (> assets u0)
        u10000  ;; Max ratio if assets present
        u0
    )
)

;; Safety Functions

;; Suspend/resume the platform
(define-public (adjust-system-status (suspended bool))
    (begin
        (asserts! (is-eq tx-sender admin-account) ERR-PERMISSION-DENIED)
        (var-set system-suspended suspended)
        (ok suspended)
    )
)

;; Enable crisis mode
(define-public (adjust-crisis-mode (enabled bool))
    (begin
        (asserts! (is-eq tx-sender admin-account) ERR-PERMISSION-DENIED)
        (var-set crisis-mode enabled)
        (ok enabled)
    )
)