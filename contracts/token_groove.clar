;; TokenGroove Contract
(define-non-fungible-token track uint)

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-invalid-points (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-rate-limit (err u106))
(define-constant err-invalid-ipfs (err u107))

;; Contract Version Control
(define-data-var contract-version uint u1)

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var last-version uint u0)
(define-data-var stream-cooldown uint u3600) ;; 1 hour cooldown

;; Enhanced Data Maps
(define-map track-data uint {
    artist: principal,
    title: (string-ascii 50),
    price: uint,
    royalty-percent: uint,
    ipfs-hash: (string-ascii 64),
    version: uint,
    total-streams: uint,
    last-updated: uint
})

(define-map stream-count {track-id: uint} {count: uint})
(define-map artist-revenue principal uint)
(define-map user-points principal uint)
(define-map reward-thresholds uint uint)
(define-map user-last-stream {user: principal, track-id: uint} uint)

;; Enhanced Events
(define-data-var event-counter uint u0)

(define-private (emit-track-event (event-type (string-ascii 20)) (track-id uint) (metadata (optional (string-ascii 256))))
    (begin
        (var-set event-counter (+ (var-get event-counter) u1))
        (print {
            event-id: (var-get event-counter),
            type: event-type,
            track: track-id,
            timestamp: block-height,
            metadata: metadata
        })
    )
)

;; Enhanced Admin Functions
(define-public (set-contract-pause (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused paused)
        (emit-track-event "contract-pause" u0 (some (if paused "paused" "unpaused")))
        (ok true)
    )
)

(define-public (set-stream-cooldown (new-cooldown uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set stream-cooldown new-cooldown)
        (ok true)
    )
)

;; Enhanced IPFS Validation
(define-private (is-valid-ipfs-hash (hash (string-ascii 64)))
    (begin
        (asserts! (is-eq (slice hash 0 2) "Qm") false)
        (asserts! (>= (len hash) u46) false)
        true
    )
)

;; Enhanced Minting Function
(define-public (mint-track (track-id uint) 
                         (title (string-ascii 50))
                         (price uint)
                         (royalty-percent uint)
                         (ipfs-hash (string-ascii 64)))
    (let ((artist tx-sender))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (not (nft-get-owner? track track-id)) err-token-exists)
        (asserts! (> price u0) err-invalid-price)
        (asserts! (<= royalty-percent u100) err-invalid-price)
        (asserts! (is-valid-ipfs-hash ipfs-hash) err-invalid-ipfs)
        (try! (nft-mint? track track-id artist))
        (var-set last-version (+ (var-get last-version) u1))
        (map-set track-data track-id {
            artist: artist,
            title: title,
            price: price,
            royalty-percent: royalty-percent,
            ipfs-hash: ipfs-hash,
            version: (var-get last-version),
            total-streams: u0,
            last-updated: block-height
        })
        (emit-track-event "mint" track-id (some title))
        (ok true)
    )
)

;; Rate-Limited Stream Function
(define-public (stream-track (track-id uint))
    (let (
        (user tx-sender)
        (last-stream (default-to u0 (get-last-stream user track-id)))
        (cooldown (var-get stream-cooldown))
    )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (>= (- block-height last-stream) cooldown) err-rate-limit)
        (try! (process-stream track-id user))
        (map-set user-last-stream {user: user, track-id: track-id} block-height)
        (emit-track-event "stream" track-id none)
        (ok true)
    )
)

;; Helper Functions
(define-private (get-last-stream (user principal) (track-id uint))
    (get-or-default-value 
        (map-get? user-last-stream {user: user, track-id: track-id})
        u0
    )
)

(define-private (get-or-default-value (value (optional uint)) (default uint))
    (match value
        value value
        default
    )
)
