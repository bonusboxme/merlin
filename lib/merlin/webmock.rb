WebMock.disable_net_connect!(allow: /herokuapp.com/) if Rails.env.test?