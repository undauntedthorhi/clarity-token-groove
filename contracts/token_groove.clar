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

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var last-version uint u0)

(define-map track-data uint {
    artist: principal,
    title: (string-ascii 50),
    price: uint,
    royalty-percent: uint,
    ipfs-hash: (string-ascii 64),
    version: uint
})

(define-map stream-count {track-id: uint} {count: uint})
(define-map artist-revenue principal uint)
(define-map user-points principal uint)
(define-map reward-thresholds uint uint)
(define-map user-last-stream {user: principal, track-id: uint} uint)

;; Events
(define-data-var event-counter uint u0)

(define-private (emit-track-event (event-type (string-ascii 20)) (track-id uint))
    (begin
        (var-set event-counter (+ (var-get event-counter) u1))
        (print {event-id: (var-get event-counter), type: event-type, track: track-id})
    )
)

;; Admin Functions
(define-public (set-contract-pause (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused paused)
        (ok true)
    )
)

;; Initialize reward thresholds
(map-set reward-thresholds u1 u100) ;; Bronze: 100 points
(map-set reward-thresholds u2 u500) ;; Silver: 500 points
(map-set reward-thresholds u3 u1000) ;; Gold: 1000 points

;; Mint new track NFT
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
            version: (var-get last-version)
        })
        (emit-track-event "mint" track-id)
        (ok true)
    )
)

;; Helper function to validate IPFS hash
(define-private (is-valid-ipfs-hash (hash (string-ascii 64)))
    (begin
        (asserts! (is-eq (slice hash 0 2) "Qm") false)
        true
    )
)

[... rest of the contract with similar enhancements ...]
