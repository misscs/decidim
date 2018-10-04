# frozen_string_literal: true

if !Rails.env.production? || ENV["SEED"]
  print "Creating seeds for decidim-core...\n" unless Rails.env.test?

  require "decidim/faker/localized"

  seeds_root = File.join(__dir__, "seeds")

  organization = Decidim::Organization.first || Decidim::Organization.create!(
    name: Faker::Company.name,
    twitter_handler: Faker::Hipster.word,
    facebook_handler: Faker::Hipster.word,
    instagram_handler: Faker::Hipster.word,
    youtube_handler: Faker::Hipster.word,
    github_handler: Faker::Hipster.word,
    host: ENV["DECIDIM_HOST"] || "localhost",
    description: Decidim::Faker::Localized.wrapped("<p>", "</p>") do
      Decidim::Faker::Localized.sentence(15)
    end,
    default_locale: Decidim.default_locale,
    available_locales: Decidim.available_locales,
    reference_prefix: Faker::Name.suffix,
    available_authorizations: Decidim.authorization_workflows.map(&:name),
    tos_version: Time.current
  )

  if organization.top_scopes.none?
    province = Decidim::ScopeType.create!(
      name: Decidim::Faker::Localized.literal("province"),
      plural: Decidim::Faker::Localized.literal("provinces"),
      organization: organization
    )

    municipality = Decidim::ScopeType.create!(
      name: Decidim::Faker::Localized.literal("municipality"),
      plural: Decidim::Faker::Localized.literal("municipalities"),
      organization: organization
    )

    3.times do
      parent = Decidim::Scope.create!(
        name: Decidim::Faker::Localized.literal(Faker::Address.unique.state),
        code: Faker::Address.unique.country_code,
        scope_type: province,
        organization: organization
      )

      5.times do
        Decidim::Scope.create!(
          name: Decidim::Faker::Localized.literal(Faker::Address.unique.city),
          code: parent.code + "-" + Faker::Address.unique.state_abbr,
          scope_type: municipality,
          organization: organization,
          parent: parent
        )
      end
    end
  end

  territorial = Decidim::AreaType.create!(
    name: Decidim::Faker::Localized.literal("territorial"),
    plural: Decidim::Faker::Localized.literal("territorials"),
    organization: organization
  )

  sectorial = Decidim::AreaType.create!(
    name: Decidim::Faker::Localized.literal("sectorials"),
    plural: Decidim::Faker::Localized.literal("sectorials"),
    organization: organization
  )

  3.times do
    Decidim::Area.create!(
      name: Decidim::Faker::Localized.word,
      area_type: territorial,
      organization: organization
    )
  end

  5.times do
    Decidim::Area.create!(
      name: Decidim::Faker::Localized.word,
      area_type: sectorial,
      organization: organization
    )
  end

  admin = Decidim::User.find_or_initialize_by(email: "admin@example.org")

  admin.update!(
    name: Faker::Name.name,
    nickname: Faker::Twitter.unique.screen_name,
    password: "decidim123456",
    password_confirmation: "decidim123456",
    organization: organization,
    confirmed_at: Time.current,
    locale: I18n.default_locale,
    admin: true,
    tos_agreement: true,
    personal_url: Faker::Internet.url,
    about: Faker::Lorem.paragraph(2),
    accepted_tos_version: organization.tos_version
  )

  regular_user = Decidim::User.find_or_initialize_by(email: "user@example.org")

  regular_user.update!(
    name: Faker::Name.name,
    nickname: Faker::Twitter.unique.screen_name,
    password: "decidim123456",
    password_confirmation: "decidim123456",
    confirmed_at: Time.current,
    locale: I18n.default_locale,
    organization: organization,
    tos_agreement: true,
    personal_url: Faker::Internet.url,
    about: Faker::Lorem.paragraph(2),
    accepted_tos_version: organization.tos_version
  )

  Decidim::Messaging::Conversation.start!(
    originator: admin,
    interlocutors: [regular_user],
    body: "Hei! I'm glad you like Decidim"
  )

  Decidim::User.find_each do |user|
    [nil, Time.current].each do |verified_at|
      user_group = Decidim::UserGroup.create!(
        name: Faker::Company.unique.name,
        nickname: Faker::Twitter.unique.screen_name,
        extended_data: {
          document_number: Faker::Number.number(10),
          phone: Faker::PhoneNumber.phone_number,
          verified_at: verified_at
        },
        decidim_organization_id: user.organization.id
      )

      Decidim::UserGroupMembership.create!(
        user: user,
        user_group: user_group
      )
    end
  end

  Decidim::OAuthApplication.create!(
    name: "Test OAuth application",
    organization_name: "Example organization",
    organization_url: "http://www.example.org",
    organization_logo: File.new(File.join(seeds_root, "homepage_image.jpg")),
    redirect_uri: "https://www.example.org/oauth/decidim",
    scopes: "public",
    organization: organization
  )

  Decidim::System::CreateDefaultContentBlocks.call(organization)

  hero_content_block = Decidim::ContentBlock.find_by(organization: organization, manifest_name: :hero, scope: :homepage)
  hero_content_block.images_container.background_image = File.new(File.join(seeds_root, "homepage_image.jpg"))
  settings = {}
  welcome_text = Decidim::Faker::Localized.sentence(5)
  settings = welcome_text.inject(settings) { |acc, (k, v)| acc.update("welcome_text_#{k}" => v) }
  hero_content_block.settings = settings
  hero_content_block.save!
end
