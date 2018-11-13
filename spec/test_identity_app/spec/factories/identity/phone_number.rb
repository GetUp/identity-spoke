FactoryBot.define do
  factory :phone_number do
    factory :mobile_number do
      phone { "614#{::Kernel.rand(10_000_000..99_999_999)}" }
      phone_type { 'mobile' }
    end
    factory :landline_number do
      phone { "612#{::Kernel.rand(10_000_000..99_999_999)}" }
      phone_type { 'landline' }
    end
  end
end
