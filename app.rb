require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/reloader' if development?
require 'aws-sdk'
require 'json'

configure do
  config_file "config.yml"
end

#### List S3 objects in a specified bucket and prefix
get '/s3/?:bucket?/?:prefix?/?' do
  protected!
  return generate_form if params[:bucket].nil? and params[:prefix].nil?
  credentials = get_credentials(@auth.username)
  bucket_name = params[:bucket]
  prefix = params[:prefix]
  
  get_s3_objects(credentials, bucket_name, prefix)
end

##### Show credentials in JSON format
get '/get_credentials' do
  protected!
  content_type :json
  credentials = get_credentials(@auth.username)
  
  pretty_output_credentials credentials
end

helpers do
  ##### Generate form
  def generate_form
    "<p><form method='get' action=''>" +
    "<label for='bucket'>Bucket: </label><input type='text' name='bucket' id='bucket'><br />" +
    "<label for='prefix'>Prefix: </label><input type='text' name='prefix' id='prefix'><br />" +
    "<input type='submit' value='List S3 Objects' onclick='document.location.href = &quot;/s3/&quot; + form.bucket.value + &quot;/&quot; + form.prefix.value; return false;'>" +
    "</form></p>"
  end
  ##### Generate HTML UL of S3 objects
  def get_s3_objects(credentials, bucket_name, prefix)
    begin
      s3 = AWS::S3.new(credentials.credentials)
      bucket = s3.buckets[bucket_name]
      output = "<h3>" + bucket_name + "</h3>"
      output += "<ul>"
      bucket.objects.with_prefix(prefix).each do |object|
        output += "<li>" + object.key + "</li>"
      end
      output += "</ul>"
      return output
    rescue AWS::S3::Errors::AccessDenied
      "Access denied to that bucket or prefix."
    end
  end
  
  ##### Generate JSON output with line breaks for easier reading
  def pretty_output_credentials(credentials)
    output = {
      "user_id" => credentials.user_id,
      "user_arn" => credentials.user_arn,
      "packed_policy_size" => credentials.packed_policy_size,
      "credentials" => credentials.credentials,
      "expires_at" => credentials.expires_at
    }
    JSON.pretty_generate(output)
  end
  
  ##### Get temporary IAM credentials
  def get_credentials(user)
    sts = AWS::STS.new(:access_key_id => settings.access_key,
                       :secret_access_key => settings.secret_key)
    federated_session = sts.new_federated_session( user, :policy => s3_policy(settings.bucket), :duration => 3660 )
  end
  
  def s3_policy(s3_prefix)
    policy = AWS::STS::Policy.new
    policy.allow(:actions => ["s3:*"],
                 :resources => [ "arn:aws:s3:::" + s3_prefix, "arn:aws:s3:::" + s3_prefix + "/*" ])
    policy
  end
  
  ##### Require user to authenticate
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  ##### Return true if the user is authenticated
  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    return @auth.provided? && @auth.basic? && @auth.credentials && authenticate(@auth.credentials[0], @auth.credentials[1])
  end
  
  ##### Return true if authentication is successful
  ### TODO: Re-implement this with Active Directory authentication
  def authenticate(login, pass)
    return false if login.empty? or pass.empty?
    
    if login == "test.user" and pass == "password"
      return true
    else
      return false
    end
    
  end
  
end # helpers