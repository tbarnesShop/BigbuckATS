# frozen_string_literal: true

# Adapter seam for Gmail send/sync. Tests use FakeGmail.
module GmailClient
  class << self
    attr_accessor :backend

    def send_message!(mailbox:, to:, subject:, body:, thread_id: nil, in_reply_to: nil, headers: {}, message_id: nil)
      if DemoSandbox.for_organization(mailbox.organization_id)
        id = "demo_msg_#{SecureRandom.uuid}"
        domain = mailbox.email.to_s.split("@", 2).last.presence || "bigbuck.local"
        return { id: id, thread_id: thread_id || id, rfc822_message_id: MailTransport.normalize_id(message_id) || "#{SecureRandom.uuid}@#{domain}",
                 from: mailbox.email, to: to, subject: subject, body: body, captured: true }
      end
      (backend || Null).send_message!(mailbox: mailbox, to: to, subject: subject, body: body, thread_id: thread_id,
        in_reply_to: in_reply_to, headers: headers, message_id: message_id)
    end
  end

  module Null
    module_function

    def send_message!(**)
      raise "GmailClient backend not configured"
    end
  end

  class Fake
    attr_reader :sent, :inbox

    def initialize
      @sent = []
      @inbox = []
      @seq = 0
    end

    def send_message!(mailbox:, to:, subject:, body:, thread_id: nil, in_reply_to: nil, headers: {}, message_id: nil)
      @seq += 1
      id = "msg_#{@seq}"
      thread = thread_id || "thr_#{@seq}"
      record = {
        id: id, thread_id: thread, from: mailbox.email, to: to,
        subject: subject, body: body, mailbox_email: mailbox.email,
        rfc822_message_id: MailTransport.normalize_id(message_id) || "fake-#{@seq}@fake.test",
        in_reply_to: in_reply_to, headers: headers
      }
      @sent << record
      record
    end

    def find_sent(mailbox:, rfc822_message_id:)
      wanted = MailTransport.normalize_id(rfc822_message_id)
      @sent.find { |row| row[:mailbox_email] == mailbox.email && row[:rfc822_message_id] == wanted }
    end

    def push_reply!(to_mailbox:, from:, subject:, body:, thread_id:)
      @seq += 1
      @inbox << {
        id: "msg_#{@seq}", thread_id: thread_id, from: from, to: to_mailbox,
        subject: subject, body: body
      }
    end
  end
end
