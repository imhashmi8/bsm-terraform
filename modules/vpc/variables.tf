variable "name" { type = string }
variable "cidr_block" { type = string }
variable "azs" { type = list(string) }                  # e.g., ["ap-south-1a","ap-south-1b"]
variable "public_subnet_cidrs" { type = list(string) }  # len=2
variable "private_subnet_cidrs" { type = list(string) } # len=2
variable "tags" {
  type    = map(string)
  default = {}
}

