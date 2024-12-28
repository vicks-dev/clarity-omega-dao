;; OmegaDAO Contract
;; Governance token for scientific research funding

;; Constants
(define-constant contract-owner tx-sender)
(define-constant dao-name "OmegaDAO")
(define-constant min-proposal-amount u1000)
(define-constant voting-period u144) ;; ~24 hours in blocks
(define-constant quorum-threshold u500000) ;; Minimum votes needed

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-invalid-proposal (err u102))
(define-constant err-proposal-active (err u103))
(define-constant err-proposal-ended (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-insufficient-funds (err u106))

;; Data variables
(define-data-var total-proposals uint u0)
(define-data-var treasury-balance uint u0)

;; Define DAO token
(define-fungible-token omega-token)

;; Proposal structure
(define-map proposals
    uint
    {
        creator: principal,
        title: (string-ascii 50),
        description: (string-utf8 500),
        amount: uint,
        votes-for: uint,
        votes-against: uint,
        start-block: uint,
        end-block: uint,
        executed: bool,
        funded: bool
    }
)

;; Vote tracking
(define-map has-voted
    { proposal-id: uint, voter: principal }
    bool
)

;; Public functions

;; Create new proposal
(define-public (submit-proposal (title (string-ascii 50)) (description (string-utf8 500)) (amount uint))
    (let (
        (proposal-id (var-get total-proposals))
        (token-balance (ft-get-balance omega-token tx-sender))
    )
        (asserts! (>= token-balance min-proposal-amount) err-not-member)
        (asserts! (> amount u0) err-invalid-proposal)
        
        (map-set proposals proposal-id {
            creator: tx-sender,
            title: title,
            description: description,
            amount: amount,
            votes-for: u0,
            votes-against: u0,
            start-block: block-height,
            end-block: (+ block-height voting-period),
            executed: false,
            funded: false
        })
        
        (var-set total-proposals (+ proposal-id u1))
        (ok proposal-id)
    )
)

;; Cast vote
(define-public (vote (proposal-id uint) (vote-for bool))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-invalid-proposal))
        (voter-balance (ft-get-balance omega-token tx-sender))
    )
        (asserts! (> voter-balance u0) err-not-member)
        (asserts! (not (is-some (map-get? has-voted { proposal-id: proposal-id, voter: tx-sender }))) err-already-voted)
        (asserts! (<= block-height (get end-block proposal)) err-proposal-ended)
        
        (map-set has-voted { proposal-id: proposal-id, voter: tx-sender } true)
        
        (if vote-for
            (map-set proposals proposal-id 
                (merge proposal { votes-for: (+ (get votes-for proposal) voter-balance) }))
            (map-set proposals proposal-id 
                (merge proposal { votes-against: (+ (get votes-against proposal) voter-balance) }))
        )
        (ok true)
    )
)

;; Execute approved proposal
(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-invalid-proposal))
    )
        (asserts! (> block-height (get end-block proposal)) err-proposal-active)
        (asserts! (not (get executed proposal)) err-invalid-proposal)
        (asserts! (>= (get votes-for proposal) quorum-threshold) err-invalid-proposal)
        (asserts! (> (get votes-for proposal) (get votes-against proposal)) err-invalid-proposal)
        
        (try! (stx-transfer? (get amount proposal) contract-owner (get creator proposal)))
        (map-set proposals proposal-id (merge proposal { executed: true, funded: true }))
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote-status (proposal-id uint) (voter principal))
    (map-get? has-voted { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-total-proposals)
    (ok (var-get total-proposals))
)