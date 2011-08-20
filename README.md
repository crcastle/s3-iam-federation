## About
Use AWS's Identity and Access Management service (or maybe it's called Security Token Service?) to generate temporary credentials for users in your existing authentication system.  Those temporary credentials are then used to list the objects in an S3 bucket.

## Install and run

	git clone git://github.com/crcastle/s3-iam-federation.git
	cd s3-iam-federation
	bundle install
	ruby app.rb
