class User < ActiveRecord::Base

  attr_accessible :first_name, :last_name, :email, :gender, :access_token, :fb_uid, :points
  has_many :invities

  before_save :create_remember_token

  def self.fetch_details(code)
    token = $oauth.get_access_token(code)
    user_details = Koala::Facebook::API.new(token).get_object("me")
    user = find_or_initialize_by_email(user_details["email"]).tap do |u|
      u.first_name = user_details["first_name"]
      u.last_name = user_details["last_name"]
      u.email = user_details["email"]
      u.gender = user_details["gender"]
      u.fb_uid = user_details["id"]
      u.access_token = token
      u.save
    end
  end

  def name
    [first_name,last_name].join(" ")
  end

  def store_invities(tos = {})
    invited_name = {}
    tos.values.each do |to_id|
      to_details = oauth.fql_query("select name,first_name,last_name from user where uid = #{to_id}")[0]
      invited_name[to_id] = to_details["name"]
      if self.invities.create(:fb_uid => to_id,:first_name => to_details["first_name"], :last_name => to_details["last_name"]).new_record?
        self.errors.add(:base, "#{to_details["name"]}: You have already get points for inviting this friend!")
      else
        self.points = self.points.to_i + 10
        self.save
      end
    end
    oauth.put_connections("me", "feed", :message => "@#{self.name} has earned free Points for inviting " + invited_name.values.map{|x| "@#{x}"}.join(" "))
  end

  def oauth
    Koala::Facebook::API.new(access_token)
  end

  private
    def create_remember_token
      self.remember_token = SecureRandom.urlsafe_base64
    end

end