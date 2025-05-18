;; Sales Tracking Contract
;; Monitors purchase patterns in the decentralized retail system

(define-data-var contract-owner principal tx-sender)

;; Sale data structure
(define-map sales
  { sale-id: uint }
  {
    store-id: uint,
    product-id: uint,
    quantity: uint,
    price-per-unit: uint,
    total-price: uint,
    timestamp: uint,
    customer: (optional principal)
  }
)

;; Sale ID counter
(define-data-var next-sale-id uint u1)

;; Store sales summary
(define-map store-sales
  { store-id: uint }
  {
    total-sales: uint,
    total-revenue: uint,
    last-sale-timestamp: uint
  }
)

;; Product sales summary
(define-map product-sales
  { product-id: uint }
  {
    total-quantity-sold: uint,
    total-revenue: uint,
    last-sale-timestamp: uint
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-SALE-NOT-FOUND u102)
(define-constant ERR-INVALID-QUANTITY u103)

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Record a new sale
(define-public (record-sale
  (store-id uint)
  (product-id uint)
  (quantity uint)
  (price-per-unit uint)
  (customer (optional principal))
)
  (let (
    (sale-id (var-get next-sale-id))
    (total-price (* quantity price-per-unit))
    (current-time (unwrap-panic (get-block-info? time u0)))
  )
    (asserts! (> quantity u0) (err ERR-INVALID-QUANTITY))

    ;; Record the sale
    (map-set sales
      { sale-id: sale-id }
      {
        store-id: store-id,
        product-id: product-id,
        quantity: quantity,
        price-per-unit: price-per-unit,
        total-price: total-price,
        timestamp: current-time,
        customer: customer
      }
    )

    ;; Update store sales summary
    (match (map-get? store-sales { store-id: store-id })
      existing-store-data
        (map-set store-sales
          { store-id: store-id }
          {
            total-sales: (+ (get total-sales existing-store-data) u1),
            total-revenue: (+ (get total-revenue existing-store-data) total-price),
            last-sale-timestamp: current-time
          }
        )
      ;; If no existing data, create new entry
      (map-set store-sales
        { store-id: store-id }
        {
          total-sales: u1,
          total-revenue: total-price,
          last-sale-timestamp: current-time
        }
      )
    )

    ;; Update product sales summary
    (match (map-get? product-sales { product-id: product-id })
      existing-product-data
        (map-set product-sales
          { product-id: product-id }
          {
            total-quantity-sold: (+ (get total-quantity-sold existing-product-data) quantity),
            total-revenue: (+ (get total-revenue existing-product-data) total-price),
            last-sale-timestamp: current-time
          }
        )
      ;; If no existing data, create new entry
      (map-set product-sales
        { product-id: product-id }
        {
          total-quantity-sold: quantity,
          total-revenue: total-price,
          last-sale-timestamp: current-time
        }
      )
    )

    (var-set next-sale-id (+ sale-id u1))
    (ok sale-id)
  )
)

;; Get sale information
(define-read-only (get-sale (sale-id uint))
  (match (map-get? sales { sale-id: sale-id })
    sale-data (ok sale-data)
    (err ERR-SALE-NOT-FOUND)
  )
)

;; Get store sales summary
(define-read-only (get-store-sales-summary (store-id uint))
  (match (map-get? store-sales { store-id: store-id })
    store-data (ok store-data)
    (ok {
      total-sales: u0,
      total-revenue: u0,
      last-sale-timestamp: u0
    })
  )
)

;; Get product sales summary
(define-read-only (get-product-sales-summary (product-id uint))
  (match (map-get? product-sales { product-id: product-id })
    product-data (ok product-data)
    (ok {
      total-quantity-sold: u0,
      total-revenue: u0,
      last-sale-timestamp: u0
    })
  )
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
