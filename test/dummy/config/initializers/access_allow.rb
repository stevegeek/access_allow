AccessAllow.configure do |config|
  config.roles_and_permissions = {
    user: {
      owner: {
        test: {
          ability1: true
        }
      }
    }
  }
end
