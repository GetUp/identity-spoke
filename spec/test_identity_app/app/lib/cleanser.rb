class Cleanser
  ########## Email cleansing ##########
  def self.cleanse_email(raw_email)
    raw_email = raw_email.to_s
    return nil if raw_email.empty?

    # do basic cleansing
    email = raw_email.downcase
    email = email.gsub(/\s/, '')
    email = email.gsub('%40', '@') # remove html entities

    account = email.split('@').first
    domain = self.fix_typos_in_domain(email.split('@').last)

    email = "#{account}@#{domain}"
    return nil unless accept_email?(email)

    email
  end

  def self.accept_email?(email_address)
    # The RFC for emails limits their length to 254 characters.
    # Gmail usernames are limited to 30 characters.  So it seems likely this standard is enforced
    Member::EMAIL_VALIDATION_REGEX.match?(email_address) && email_address.length < 255
  end

  def self.fix_typos_in_domain(domain)
    # try and correct some common domain patterns
    return 'gmail.com' if ['gmail.co', 'gmial.com', 'gmail.cm', 'gmail.com.uk', 'gnail.com'].include?(domain)
    return 'hotmail.com' if ['hotmail.co', 'hitmail.com', 'hormail.com', 'hotnail.com', 'hotmsil.com', 'hotmai.com', 'hptmail.com', 'homail.com'].include?(domain)
    return 'hotmail.co.uk' if ['hotmail.com.uk', 'hitmail.co.uk', 'hormail.co.uk', 'hotnail.co.uk', 'hotmsil.co.uk', 'hotmai.co.uk', 'hptmail.co.uk', 'homail.co.uk'].include?(domain)
    return 'btinternet.com' if ['btinternet.cm', 'btinterent.com', 'byinternet.com', 'brinternet.com'].include?(domain)
    return 'yahoo.com' if ['yaho.com', 'yahoo.co', 'yshoo.com', 'tahoo.com', 'ayhoo.com'].include?(domain)
    return 'yahoo.co.uk' if ['yahooco.uk', 'yahoo.ci.uk', 'yahoo.com.uk', 'yshoo.co.uk', 'tahoo.co.uk', 'ayhoo.co.uk', 'yahoo.cp.uk'].include?(domain)

    domain
  end

  ########## Phone Number cleansing ##########
  # detects if a given phone number is a mobile number
  def self.is_mobile_number?(phone_number)
    if Settings.sms.twilio.use_lookup_for_numbers
      lookup_number_twilio(phone_number)
    elsif Settings.sms.pinpoint.use_lookup_for_numbers
      lookup_number_pinpoint(phone_number)
    elsif Settings.app.country == 'gb'
      phone_number.starts_with?('447')
    elsif Settings.app.country == 'au'
      phone_number.starts_with?('614')
    else
      true
    end
  end

  ##### Support for different phone number lookup services
  def self.lookup_number_twilio(phone_number)
    twilio = Twilio::REST::Client.new(Settings.sms.twilio.account_id, Settings.sms.twilio.auth_token)
    response = twilio.lookups.phone_numbers(phone_number).fetch(type: 'carrier')
    response.carrier['type'].eql?('mobile')
  end

  def self.lookup_number_pinpoint(phone_number)
    pinpoint = Aws::Pinpoint::Client.new(
      access_key_id: Settings.aws.access_key_id,
      secret_access_key: Settings.aws.secret_access_key,
      region: Settings.aws.region
    )
    query = { number_validate_request: { phone_number: "+#{phone_number}" } }
    begin
      response = pinpoint.phone_number_validate(query).number_validate_response
      return ['MOBILE', 'PREPAID'].include?(response.phone_type)
    rescue Aws::Pinpoint::Errors::ServiceError => e
      Rails.logger.error "Phone number: #{phone_number}. #{e.message}"
      return false
    end
  end

  ########## General text/input cleansing ##########
  def self.replace_smart_quotes(string)
    string.gsub(/[\u201c\u201d]/, '"').gsub(/[\u2018\u2019]/, "'")
  end
end
