variable "project" {
  default = "roboshop"
}

variable "environment" {
  default = "dev"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# mandatory to provide
variable "security_group" {
  type    = list(string)
  default = ["value"]
}

variable "zone_name" {
  default = "satyology.site"
}


variable "common_tags" {
  type = map(string)
  default = {
    "Name"      = "roboshop"
    "Terraform" = "true"
    "Version"   = "1.0"
  }
}

variable "component" {
  type = string
}

variable "priority" {

}