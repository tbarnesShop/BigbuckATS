# frozen_string_literal: true

# One contract every MailTransport backend must satisfy, so threading and
# idempotent retry behave the same on Sandbox and on Gmail.
# Including classes define: transport_mailbox, recipient.
module MailTransportContract
  def deliver(**args)
    MailTransport.deliver!(mailbox: transport_mailbox, to: recipient, subject: "Hello", body: "Body", **args)
  end

  def test_deliver_returns_ids
    result = deliver
    assert result[:id].present?
    assert result[:thread_id].present?
    assert result[:rfc822_message_id].present?
    refute_match(/[<>]/, result[:rfc822_message_id])
  end

  def test_deliver_keeps_a_caller_supplied_message_id
    result = deliver(message_id: "<fixed-1@contract.test>")
    assert_equal "fixed-1@contract.test", result[:rfc822_message_id]
  end

  def test_find_sent_returns_the_delivered_message_by_id
    deliver(message_id: "<find-me@contract.test>")
    found = MailTransport.find_sent(mailbox: transport_mailbox, rfc822_message_id: "find-me@contract.test")
    refute_nil found
    assert_equal "find-me@contract.test", found[:rfc822_message_id]
    found_bracketed = MailTransport.find_sent(mailbox: transport_mailbox, rfc822_message_id: "<find-me@contract.test>")
    refute_nil found_bracketed
  end

  def test_find_sent_is_nil_for_an_unknown_id
    assert_nil MailTransport.find_sent(mailbox: transport_mailbox, rfc822_message_id: "never-sent@contract.test")
  end

  def test_reply_stays_on_the_same_thread
    first = deliver
    second = deliver(thread_id: first[:thread_id], in_reply_to: first[:rfc822_message_id])
    assert_equal first[:thread_id], second[:thread_id]
    refute_equal first[:rfc822_message_id], second[:rfc822_message_id]
  end
end
