# frozen_string_literal: true

# Facility Access: QR codes that open the door, and checking them at the door.
# Context map: ACL downstream of Reservations. Upstream of nobody, so it has no public events.
module FacilityAccess
  AccessToCoworkGranted = Class.new(RubyEventStore::Event)   # pass_id, booking_ref, holder, zone, valid_on, from_hour, to_hour
  CodesSent = Class.new(RubyEventStore::Event)               # pass_id, recipient
  QrCodeScanned = Class.new(RubyEventStore::Event)           # code, at
  QrCodeAccepted = Class.new(RubyEventStore::Event)          # code, pass_id
  QrCodeRejected = Class.new(RubyEventStore::Event)          # code, reason
  CustomerServiceNotified = Class.new(RubyEventStore::Event) # code, reason
end
