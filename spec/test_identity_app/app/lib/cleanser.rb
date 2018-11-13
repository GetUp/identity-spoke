class Cleanser
  def self.cleanse_email(raw_email)
    raw_email = raw_email.to_s
    return nil if raw_email.empty?

    # do basic cleansing
    email = raw_email.downcase
    email = email.delete(' ') # remove spaces
    email = email.gsub('%40', '@') # remove html entities

    # try and correct some common domain patterns
    replacements = [
      { from: 'hotmail.co', to: 'hotmail.com' },
      { from: 'gmail.co', to: 'gmail.com' },
      { from: 'hitmail.com', to: 'hotmail.com' },
      { from: 'hitmail.co.uk', to: 'hotmail.co.uk' }
    ]

    account = email.split('@').first
    domain = email.split('@').last

    replacements.each do |replacement|
      domain = replacement[:to] if domain == replacement[:from]
    end

    email = "#{account}@#{domain}"
    return nil unless accept_email?(email)
    email
  end

  # this is an intentionally very basic email check, as from everything I've read, actuallly
  # validating emails is a nightmare. Let's check it at least looks vaguely okay, then if it bounces
  # we can remove it
  def self.accept_email?(email_address)
    /@/.match(email_address)
  end

  # detects if a given phone number is a mobile number
  def self.is_mobile_number?(phone_number)
    if Settings.sms.twilio.use_lookup_for_numbers
      twilio = Twilio::REST::Client.new(Settings.sms.twilio.account_id, Settings.sms.twilio.auth_token)
      response = twilio.lookups.phone_numbers(phone_number).fetch(type: 'carrier')
      response.carrier['type'].eql?('mobile')
    elsif Settings.app.country == 'gb'
      phone_number.starts_with?('447')
    elsif Settings.app.country == 'au'
      phone_number.starts_with?('614')
    else
      true
    end
  end
end
