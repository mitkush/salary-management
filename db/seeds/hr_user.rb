User.find_or_create_by!(email_address: ENV.fetch("HR_EMAIL", "hr@example.com")) do |user|
  user.password = ENV.fetch("HR_PASSWORD", "password")
end
