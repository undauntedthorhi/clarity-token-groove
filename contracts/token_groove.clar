;; TokenGroove Contract
(define-non-fungible-token track uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-invalid-price (err u103))

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
        (ok true)
    )
)

;; Record stream
(define-public (record-stream (track-id uint))
    (let (
        (current-count (default-to {count: u0} (map-get? stream-count {track-id: track-id})))
    )
        (map-set stream-count 
            {track-id: track-id}
            {count: (+ u1 (get count current-count))}
        )
        (ok true)
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