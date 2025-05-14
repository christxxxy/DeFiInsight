;; DeFiInsight Platform - Initial Implementation
;; Version 1.0

;; Primary Constants
(define-constant admin-account tx-sender)
(define-constant ERR-PERMISSION-DENIED (err u4001))
(define-constant ERR-QUANTITY-INVALID (err u4003))
(define-constant ERR-STX-BALANCE-LOW (err u4004))
(define-constant ERR-THRESHOLD-UNMET (err u4007))
(define-constant ERR-SYSTEM-SUSPENDED (err u4008))

;; Platform Token Definition
(define-fungible-token INSIGHT-TOKEN)

;; System Status Variables
(define-data-var system-suspended bool false)

;; Participation Parameters
(define-data-var stx-reserve uint u0)
(define-data-var default-yield uint u500) ;; 5% standard rate (100 = 1%)
(define-data-var entry-threshold uint u1000000) ;; Minimum participation amount

;; Basic Data Structures
(define-map ParticipantMetrics
    principal
    {
        stx-committed: uint,
        platform-tokens: uint,
        latest-activity: uint,
        membership-level: uint
    }
)

(define-map MembershipTiers
    uint  ;; membership level
    {
        threshold-requirement: uint,
        tier-booster: uint
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
                tier-booster: u100     ;; 1x
            })
        (map-set MembershipTiers u2
            {
                threshold-requirement: u5000000,  ;; 5M uSTX
                tier-booster: u150     ;; 1.5x
            })
        (map-set MembershipTiers u3
            {
                threshold-requirement: u10000000, ;; 10M uSTX
                tier-booster: u200     ;; 2x
            })
        
        (ok true)
    )
)

;; Commit STX to the platform
(define-public (commit-stx (quantity uint))
    (let
        (
            (current-metrics (default-to 
                {
                    stx-committed: u0,
                    platform-tokens: u0,
                    latest-activity: u0,
                    membership-level: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
        )
        (asserts! (not (var-get system-suspended)) ERR-SYSTEM-SUSPENDED)
        (asserts! (>= quantity (var-get entry-threshold)) ERR-THRESHOLD-UNMET)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? quantity tx-sender (as-contract tx-sender)))
        
        ;; Calculate tier
        (let
            (
                (new-total-commitment (+ (get stx-committed current-metrics) quantity))
                (membership-info (evaluate-membership-level new-total-commitment))
            )
            
            ;; Update participant metrics with new tier data
            (map-set ParticipantMetrics
                tx-sender
                (merge current-metrics
                    {
                        stx-committed: new-total-commitment,
                        membership-level: membership-info,
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

;; Withdraw STX from the platform
(define-public (withdraw-stx (quantity uint))
    (let
        (
            (current-metrics (default-to 
                {
                    stx-committed: u0,
                    platform-tokens: u0,
                    latest-activity: u0,
                    membership-level: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
            (current-committed (get stx-committed current-metrics))
        )
        (asserts! (not (var-get system-suspended)) ERR-SYSTEM-SUSPENDED)
        (asserts! (<= quantity current-committed) ERR-STX-BALANCE-LOW)
        
        ;; Transfer STX from contract
        (try! (as-contract (stx-transfer? quantity tx-sender tx-sender)))
        
        ;; Calculate new tier after withdrawal
        (let
            (
                (new-total-commitment (- current-committed quantity))
                (membership-info (evaluate-membership-level new-total-commitment))
            )
            
            ;; Update participant metrics with new tier data
            (map-set ParticipantMetrics
                tx-sender
                (merge current-metrics
                    {
                        stx-committed: new-total-commitment,
                        membership-level: membership-info,
                        latest-activity: block-height
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
                    membership-level: u0
                }
                (map-get? ParticipantMetrics tx-sender)))
            (blocks-passed (- block-height (get latest-activity current-metrics)))
            (committed-amount (get stx-committed current-metrics))
            (tier (get membership-level current-metrics))
            (tier-boost (get tier-booster (default-to {threshold-requirement: u0, tier-booster: u100} 
                                         (map-get? MembershipTiers tier))))
        )
        (asserts! (> committed-amount u0) ERR-STX-BALANCE-LOW)
        
        ;; Calculate rewards
        (let
            (
                (standard-yield (/ (* committed-amount blocks-passed (var-get default-yield)) u1000000))
                (boosted-yield (/ (* standard-yield tier-boost) u100))
            )
            
            ;; Mint reward tokens
            (try! (ft-mint? INSIGHT-TOKEN boosted-yield tx-sender))
            
            ;; Update participant metrics
            (map-set ParticipantMetrics
                tx-sender
                (merge current-metrics
                    {
                        platform-tokens: (+ (get platform-tokens current-metrics) boosted-yield),
                        latest-activity: block-height
                    }
                )
            )
            
            (ok boosted-yield)
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

;; Admin Functions

;; Suspend/resume the platform
(define-public (adjust-system-status (suspended bool))
    (begin
        (asserts! (is-eq tx-sender admin-account) ERR-PERMISSION-DENIED)
        (var-set system-suspended suspended)
        (ok suspended)
    )
)