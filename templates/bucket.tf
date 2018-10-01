// keep state remotely with s3
// terraform.backend configuration cannot contain interpolations!

terraform {
  backend "s3" {
    encrypt    = true
    bucket     = ""
    endpoint   = ""
    key        = "./terraform.tfstate"
    region     = ""
    access_key = ""
    secret_key = ""
  }
}
