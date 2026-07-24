terraform { 
  required_providers { 
    aws = { 
      source  = "hashicorp/aws" 
      version = "5.84.0" # <-- Remove the ~> so it is EXACTLY 5.84.0
    } 
  } 
} 

provider "aws" { 
  region = "us-east-1" 
}

