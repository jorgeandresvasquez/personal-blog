---
title: Managing IAC like a Rockstar using Terraform
date: 2019-10-16 23:43:41
tags:
---
Getting started with technologies these days is easy, there's plenty of introductory articles and most technology providers will keep dedicated teams for writing and keeping up-to-date technical documentation with titles such as `Getting started with xxxx`. `10 minute intro to xxxxx`, `Quick intro to...`  Terraform is no exception to this and they have great entry level documentation here:  
- [Intro to Terraform](https://www.terraform.io/intro/index.html).
- [Getting started with Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html).

The documentation here is definitely top quality but leaves you that feeling -that most hello worlds have on you- like you're just grasping the surface and there's lots of problems that complex, enterprise-level projects have that remain unanswered.
Everybody has a different learning style, but my personal preference is learned lessons by a mix of theory and examples (I am a big fan of all books finishing by `...in Action`).  This article is meant to go a little deeper into Terraform by addressing the creation of a blog site in AWS S3.  During this process the following questions will be answered as the article progresses:
1. How do we define modules that are reusable by a team using Terraform?
2. How do we separate the IAC between different environments while achieving [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)?
    - Here it is worth noting that IAC is after all code and the best coding practices that have been refined over the years for software systems are also applicable to IAC.[Reference][1]  
3. How do we setup automated testing for our IAC?

Before proceeding I will take some time to define terraform and define it's relevancy in the DevOps universe.
Let's begin by saying that Devops is actually one of the best coined buzzwords that I actually have encountered throughout my career.  There are a lo of buzzwords that are unclear and confusing such as Microservices, Digital Transformation, Web 2.0, etc.  The word Devops is actually very rich semantically and contains the core meaning in the word itself which is a better collaboration between Developers and Operations teams, in some cases almost being interdisciplinary and having the same people doing both tasks.  It is very important to clarify a KEY element here which is the development aspect in DEVOPS.  This movement hugely embraces development as the automation element and therefore brings a lot of Software Engineering elements to the hardware and infrastructure world.

So now back to defining Terraform and the kind of tool it is.  Terraform is a tool to provision Infrastructure.  Provisioning means to `bring infrastructure resources to life`.  Terraform uses a declarative approach and tracks the state of the resources that you tell it to track.  The interesting aspect here is that you don't need to track the `HOW` to arrive to a specific state, you just have to worry about the `WHAT`, terraform does the rest, it basically takes care of understanding the differences between an infrastructure's current state and the most recent state that it recorded and does a diff between both and figures out the most optimal path to arrive to the new desired state.  So whenever you run terraform in the background it reads its current state of the infrastructure, reads the real state of the infrastructure and figures out how what changes are required in the real infrastructure to arrived to the desired state.  
There are 3 main pieces in the terraform equation:  
1. current known terraform state
2. new desired state 
3. actual infrastructure state.  
Terraform's typical lifecycle will compare these 3 states and identify the required changes to achieve the new desired state.  These changes can be of 3 types:  Create, Add, or Modification of resource(s).  A key notion to consider is the notion of drift, which is the deviation of your infrastructure state from the one that Terraform is tracking.  Drift can happen for example when a user modifies a resource outside of terraform using a UI (e.g the AWS console.  Terraform does its best to deal with drift so as part of its flow it identifies changes between the known and desired terraform state and the real infrastructure state and decides on the actions to take.  Note that from terraform's point of view it's end goal is the desired state, so it will identify any actions required to bring the infrastructure to the desired state.  This means that modifications that took place outside of terraform will get lost if they're not specified in the desired state.        

This article will be the first of a series of iterations using different use cases that expose best practices within Terraform by example and will progress in complexity from one use case to another.  The first use case that will be covered is the definition of a blog site using serverless technologies in AWS.

So let's be discliplined and therefore start with the first step in any software product or solution is the definition of high level requirements:
- The blog should support articles to be written in markdown (this just makes writing articles as whole much easier and can be converted easily to html, pdf, etc.)
- The blog should be as cheap as possible to run and maintain (by cheap I mean less than $5 CAD/month)
- The blog should support templates to render content consistently 
- The blog should start simple, just as a reading platform but allow to evolve with new features such as comments, comment approvals, etc.
- The blog should support a staging environment where correct display and rendering are to be tested, not accessible by the general public
- The blog should only be accesible using https
- The blog response times should be fast and scale automatically whenever there's more viewers
- The blog should support proper rendering in different screen sizes ideally with availability of templates that use responsive design

The chosen technology stack for the solution is:
- IAC Provisioning tool:  Terraform
- Blogging platform:  [Hexo](https://hexo.io/)
- Complimentary tool to fill in some Terraform gaps:  [Terragrunt](https://github.com/gruntwork-io/terragrunt)
- Tool to test terraform:  [Terratest](https://github.com/gruntwork-io/terratest)
- Tool used to document the architecture and environments visually:  draw.io vs cloudcraft.co (really cool 3D visualization but free edition has limited grid)
Note:  The goal of this article isn't to justify or explain the rationale behind the chosen technology stack, there are other great tools to manage blogs or to publish static websites out there and I don't have anything against them (Wordpress, Jekyll, etc.).

All of the code used for this article is available in the following github repository:  https://github.com/jorgeandresvasquez/personal-blog.

For the visually inclined (like me) here goes a visual representation of the infrastructure:

{% asset_img JorgePersonalBlogAWSArchitecture.png AWS Personal Blog Architecture %}

And the terraform code folder structure is as follows:

{% asset_img terraformPersonalBlogFolderStructure.png AWS Personal Blog Architecture %}

The folder structure for this system is as follows:
- dev
    - static_website
- prod
    - static_website
- mgmt (An environment for DevOps tooling (e.g., bastion host, Jenkins))
- global (A place to put resources that are used across all environments (e.g., S3, IAM))

For each component the typical files include:
- variables.tf
- output.tf
- main.tf

Notice that if we don't define modules the code above will end up with a lot of duplication.

## Steps to Create the AWS cloud environment

### Part 1:  Create Global Resources

1.  Setup credentials for AWS and variables for Terraform

``` bash
$ export AWS_ACCESS_KEY_ID=(your access key id)
$ export AWS_SECRET_ACCESS_KEY=(your secret access key)
$ export TF_VAR_db_password="(YOUR_DB_PASSWORD)"
```
2. Set the variable names for the global S3 bucket to store the terraform state and the dynamodb table for the locks in file:  `global/s3/variables.tf`

3.  Create the global Terraform resources in AWS using local state file:

``` bash
$ cd cloud/terraform/providers/aws/global
$ terraform init
$ terraform apply
```

4.  Add the following section to the file:  `global/main.tf`

``` yaml
terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "(YOUR BLOBAL S3 BUCKET NAME)"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "(YOUR DYNAMODB TABLE NAME)"
    encrypt        = true
  }
}
```

5. Move the local state file to a remote backend:
``` bash
$ cd global
$ terraform init
```

6.  Provision an SSL Certiifcate within AWS using their Certificate Manager service (ACM).
In my case I wanted all combinations of access to my blog site to be encrypted, therefore as domain name I used:  `*.thepragmaticloud.com` (www.thepragmaticloud.com, prod.thepragmaticloud.com, etc.). 
Be mindful that if you also wish to support the apex domain (Example:  `thepragmaticloud.com`) you will need to include a separate domain name for this when requesting the certificate.  (See:  https://docs.aws.amazon.com/acm/latest/userguide/acm-certificate.html)  
Also, if you have purchased your domain name via route53 in AWS then the best and easiest validation option to choose is:  `DNS validation`
Note that it usually takes around 5 minutes to issue and validate the certificate on the AWS side but they tell you that this can take up to 30 min.
Also there's a fundamental requirement of cloudfront, which is that the certificate has to be requeuested in the `us-east-1` region (N. Virginia):
```
To use an ACM Certificate with Amazon CloudFront, you must request or import the certificate in the US East (N. Virginia) region. ACM Certificates in this region that are associated with a CloudFront distribution are distributed to all the geographic locations configured for that distribution.
```
7.  Modify the terrafrom.tfvars, copy-paste the ACM Certificate ARN from the previous step and run:
``` bash
$ terraform plan -out tplan 
$ terraform apply tplan
```
Note that the above terraform execution can take around 15 minutes so this might be a good time for a coffee.
There's also a variable named:  `wait_for_deployment` that switches off the waiting of terraform for the cloudfron distribution status to change from `InProgress` to `Deployed`. 
When modifying the terraform.tfvars special attention is required for the value of `hostname` which will be both the [FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name) (Fully Qualified Domain Name) (Ex:  wwww.myblog.com or blog.jackwhite.com) to access your blog as well as the name of the bucket.  Behind the scenes when setting up a public S3 website the name of the bucket has to match with the FQDN of the website.  So in case the bucket name associated to your FQDN is already taken (S3 bucket names have to be universally unique) you won't be able to proceed with your choice.  

## Terraform best practices
So now let's look at what we just did using terraform and try to learn some lessons from the way the terraform source is structureed:
- 
- Map the folder structure to the remote state structure
- Use tags, separate them between global ones and resource-specific ones:
    - Ideas for global tags:
        - TeamOwner
        - DeployedBy
            - Ex:  terraform vs manually
        - Product
    - Ideas for tags by environment:
        - Environment
    - Ideas for resource-specific tags:
        - Name
- After you start using Terraform, you should only use Terraform
    - When a part of your infrastructure is managed by Terraform, you should never manually make changes to it. Otherwise, you not only set yourself up for weird Terraform errors, but you also void many of the benefits of using infrastructure as code in the first place, given that the code will no longer be an accurate representation of your infrastructure.
    - If you created infrastructure before you started using Terraform, you can use the terraform import command to add that infrastructure to Terraform’s state file, so that Terraform is aware of and can manage that infrastructure. The import command takes two arguments. The first argument is the “address” of the resource in your Terraform configuration files. This makes use of the same syntax as resource references, such as <PROVIDER>_<TYPE>.<NAME> (e.g., aws_iam_user.existing_user). The second argument is a resource-specific ID that identifies the resource to import. For example, the ID for an aws_iam_user resource is the name of the user (e.g., yevgeniy.brikman) and the ID for an aws_instance is the EC2 Instance ID (e.g., i-190e22e5). The documentation at the bottom of the page for each resource typically specifies how to import it.
    - Note that if you have a lot of existing resources that you want to import into Terraform, writing the Terraform code for them from scratch and importing them one at a time can be painful, so you might want to look into a tool such as [Terraforming](http://terraforming.dtan4.net/), which can import both code and state from an AWS account automatically.
- Be careful with refactoring
    - Example:  Changing names can lead to downtimes
    - use a create_before_destroy strategy when applicable for renaming
    - Use the terraform state mv command when you want to rename a terraform resource (rename it in both the tf file and then in the state with this command)
- Version pin all of your Terraform modules to a specific version of Terraform
    - For production-grade code, it is recommended to pin the version even more strictly:
    ```
    terraform {
        # Require any 0.12.x version of Terraform
        required_version = ">= 0.12, < 0.13"
    }
    provider "aws" {
        region = "us-east-2"

        # Allow any 2.x version of the AWS provider
        version = "~> 2.0"
    }
    ```
- 
## Recommended Naming Conventions

## References
[1]: [Best Coding Practices](https://en.wikipedia.org/wiki/Best_coding_practices)
https://dizzy.zone/2017/11/30/Starting-a-blog-with-hexo-and-AWS-S3/
https://hexo.io/
https://www.techiediaries.com/jekyll-hugo-hexo/
- Real world experience and proven best practices for terraform
    - https://www.hashicorp.com/resources/terraforming-real-world-experience-best-practices
- 5 Lessons Learned From Writing Over 300,000 Lines of Infrastructure Code (Excelent!!!!)
    - https://www.youtube.com/watch?v=RTEgE2lcyk4
- Wrapper around terraform by gruntwork:
    - https://github.com/gruntwork-io/terragrunt
- Checklist:
    - https://www.gruntwork.io/devops-checklist/
- Terraform up and running:
    - https://www.terraformupandrunning.com/
- https://github.com/cloudposse/
    - https://github.com/cloudposse/terraform-aws-s3-website
    - https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn
- https://registry.terraform.io/
- https://medium.com/runatlantis/hosting-our-static-site-over-ssl-with-s3-acm-cloudfront-and-terraform-513b799aec0f
    - Uses similar approach but with their own modules
- https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn
- https://medium.com/faun/how-to-host-your-static-website-with-s3-cloudfront-and-set-up-an-ssl-certificate-9ee48cd701f9
- https://github.com/terraform-aws-modules/terraform-aws-rds-aurora
- https://www.runatlantis.io/
- https://github.com/skyscrapers/terraform-website-s3-cloudfront-route53
- netlify
    - Take a look at this platform
- https://xiaoxing.us/2017/11/18/from-0-to-1-build-your-blog-using-hexo/
- Add AWS codbuild pipeline triggered by a webhook:
    - https://blog.mikeauclair.com/blog/2018/10/16/simple-static-blog-terraform.html
- https://hackernoon.com/build-a-serverless-production-ready-blog-b1583c0a5ac2
    - on s3 + hexo
- Themes for hexo:
    - https://github.com/klugjo/hexo-theme-magnetic
    - https://github.com/ppoffice/hexo-theme-icarus
- Commenting platforms:
    - https://disqus.com/pricing/
- https://xiaoxing.us/2017/11/18/from-0-to-1-build-your-blog-using-hexo/
- https://pages.github.com/


## Ideas
- Fun logo for `like a rockstar`
- Arvind to run and test it
- https://medium.com/slalom-technology
- krebsonsecurity
- The goal of these articles to help in the marketting funnel, especially by elevating awareness of Slalom and what we do.

