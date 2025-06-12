;; Channel Coordination Contract
;; Coordinates customer channels and touchpoints

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_CHANNEL_NOT_FOUND (err u201))
(define-constant ERR_INVALID_CHANNEL (err u202))
(define-constant ERR_CHANNEL_INACTIVE (err u203))

;; Data structures
(define-map channels
  { channel-id: uint }
  {
    name: (string-ascii 30),
    channel-type: (string-ascii 20),
    status: (string-ascii 10),
    priority: uint,
    coordinator: principal,
    created-at: uint,
    last-updated: uint
  }
)

(define-map channel-interactions
  { channel-id: uint, interaction-id: uint }
  {
    customer-id: (string-ascii 50),
    interaction-type: (string-ascii 20),
    timestamp: uint,
    status: (string-ascii 15),
    data-hash: (buff 32)
  }
)

(define-data-var next-channel-id uint u1)
(define-data-var next-interaction-id uint u1)

;; Create new channel
(define-public (create-channel (name (string-ascii 30)) (channel-type (string-ascii 20)) (priority uint))
  (let ((channel-id (var-get next-channel-id)))
    (map-set channels
      { channel-id: channel-id }
      {
        name: name,
        channel-type: channel-type,
        status: "active",
        priority: priority,
        coordinator: tx-sender,
        created-at: block-height,
        last-updated: block-height
      }
    )
    (var-set next-channel-id (+ channel-id u1))
    (print { event: "channel-created", channel-id: channel-id, name: name })
    (ok channel-id)
  )
)

;; Record channel interaction
(define-public (record-interaction (channel-id uint) (customer-id (string-ascii 50)) (interaction-type (string-ascii 20)) (data-hash (buff 32)))
  (let ((interaction-id (var-get next-interaction-id)))
    (asserts! (is-some (map-get? channels { channel-id: channel-id })) ERR_CHANNEL_NOT_FOUND)
    (map-set channel-interactions
      { channel-id: channel-id, interaction-id: interaction-id }
      {
        customer-id: customer-id,
        interaction-type: interaction-type,
        timestamp: block-height,
        status: "recorded",
        data-hash: data-hash
      }
    )
    (var-set next-interaction-id (+ interaction-id u1))
    (print { event: "interaction-recorded", channel-id: channel-id, interaction-id: interaction-id })
    (ok interaction-id)
  )
)

;; Update channel status
(define-public (update-channel-status (channel-id uint) (new-status (string-ascii 10)))
  (match (map-get? channels { channel-id: channel-id })
    channel-data
    (begin
      (asserts! (is-eq tx-sender (get coordinator channel-data)) ERR_UNAUTHORIZED)
      (map-set channels
        { channel-id: channel-id }
        (merge channel-data { status: new-status, last-updated: block-height })
      )
      (print { event: "channel-status-updated", channel-id: channel-id, status: new-status })
      (ok true)
    )
    ERR_CHANNEL_NOT_FOUND
  )
)

;; Get channel info
(define-read-only (get-channel (channel-id uint))
  (map-get? channels { channel-id: channel-id })
)

;; Get interaction info
(define-read-only (get-interaction (channel-id uint) (interaction-id uint))
  (map-get? channel-interactions { channel-id: channel-id, interaction-id: interaction-id })
)
