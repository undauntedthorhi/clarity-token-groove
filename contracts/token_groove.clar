;; TokenGroove Contract
(define-non-fungible-token track uint)

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-invalid-points (err u104))

;; Data Variables
(define-map track-data uint {
    artist: principal,
    title: (string-ascii 50),
    price: uint,
    royalty-percent: uint,
    ipfs-hash: (string-ascii 64)
})

(define-map stream-count {track-id: uint} {count: uint})
(define-map artist-revenue principal uint)
(define-map user-points principal uint)
(define-map reward-thresholds uint uint)

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
        (asserts! (not (nft-get-owner? track track-id)) (err err-token-exists))
        (asserts! (> price u0) (err err-invalid-price))
        (asserts! (<= royalty-percent u100) (err err-invalid-price))
        (try! (nft-mint? track track-id artist))
        (map-set track-data track-id {
            artist: artist,
            title: title,
            price: price,
            royalty-percent: royalty-percent,
            ipfs-hash: ipfs-hash
        })
        (ok true)
    )
)

;; Purchase track
(define-public (purchase-track (track-id uint))
    (let (
        (track-info (unwrap! (map-get? track-data track-id) (err u404)))
        (seller (unwrap! (nft-get-owner? track track-id) (err u404)))
        (buyer tx-sender)
        (price (get price track-info))
        (royalty (/ (* price (get royalty-percent track-info)) u100))
    )
        (try! (stx-transfer? price buyer seller))
        (try! (stx-transfer? royalty buyer (get artist track-info)))
        (try! (nft-transfer? track track-id seller buyer))
        (add-points buyer u50) ;; Award points for purchase
        (ok true)
    )
)

;; Record stream and award points
(define-public (record-stream (track-id uint))
    (let (
        (current-count (default-to {count: u0} (map-get? stream-count {track-id: track-id})))
        (user tx-sender)
    )
        (map-set stream-count 
            {track-id: track-id}
            {count: (+ u1 (get count current-count))}
        )
        (add-points user u10) ;; Award points for streaming
        (ok true)
    )
)

;; Add points to user
(define-private (add-points (user principal) (points uint))
    (let (
        (current-points (default-to u0 (map-get? user-points user)))
        (new-points (+ points current-points))
    )
        (map-set user-points user new-points)
        (ok new-points)
    )
)

;; Get user reward tier
(define-read-only (get-reward-tier (user principal))
    (let ((points (default-to u0 (map-get? user-points user))))
        (cond
            ((>= points (unwrap! (map-get? reward-thresholds u3) (err u404))) (ok u3))
            ((>= points (unwrap! (map-get? reward-thresholds u2) (err u404))) (ok u2))
            ((>= points (unwrap! (map-get? reward-thresholds u1) (err u404))) (ok u1))
            (true (ok u0))
        )
    )
)

;; Read-only functions
(define-read-only (get-track-info (track-id uint))
    (ok (map-get? track-data track-id))
)

(define-read-only (get-stream-count (track-id uint))
    (ok (get count (default-to {count: u0} (map-get? stream-count {track-id: track-id}))))
)

(define-read-only (get-artist-revenue (artist principal))
    (ok (default-to u0 (map-get? artist-revenue artist)))
)

(define-read-only (get-user-points (user principal))
    (ok (default-to u0 (map-get? user-points user)))
)
