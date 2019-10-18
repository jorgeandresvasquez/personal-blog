---
title: Managing IAC like a Rockstar using Terraform
date: 2019-10-16 23:43:41
tags: 
    - DevOps
    - Hexo
    - Terraform
categories:
    - [IAC, Terraform]
thumbnail: images/rockstar.jpg
---
Getting started with technologies these days is easy, there's plenty of introductory articles and most technology providers will keep dedicated teams for writing and keeping up-to-date technical documentation with titles such as `Getting started with xxxx`. `10 minute intro to xxxxx`, `Quick intro to...`  Terraform is no exception to this and they have great entry level documentation here:  
- [Intro to Terraform](https://www.terraform.io/intro/index.html).
- [Getting started with Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html).

The documentation here is definitely top quality but leaves you that feeling -that most hello worlds have on you- like you're just grasping the surface and there's lots of problems that complex, enterprise-level projects have that remain unanswered.
Everybody has a different learning style, but my personal preference is learned lessons by a mix of theory and examples (I am a big fan of all books finishing by `...in Action`).  

This article will be the first of a series of articles using different use cases that expose best practices within Terraform by example and will progress in complexity from one use case to another.  The first use case that will be covered is the definition of a blog site using serverless technologies in AWS.
My goal is to answer the following questions by the end of this article:
1. How do we define modules that are reusable by a team using Terraform?
2. How do we separate the IAC between different environments while achieving [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)?
    - Here it is worth noting that IAC is after all code and the best coding practices that have been refined over the years for software systems are also applicable to IAC.[Reference][1] 

Before proceeding let's define terraform and it's relevancy within the DevOps universe.
{% blockquote %}
On the subject of DevOps my personal opinion is that it is one of the best coined buzzwords that I have encountered throughout my career.  There are a LOTS of buzzwords in the IT industry and most are very unclear and confusing such as Microservices, Digital Transformation, Web 2.0, etc.  However, the word Devops is actually very rich semantically and contains the core meaning in the word itself:  "a better collaboration between Developers and Operations teams", in some cases it can end up being the same person or team doing both.  It is very important to clarify a KEY element here which is the development aspect in DEVOPS.  This movement hugely embraces development as the automation element and therefore brings a lot of Software Engineering elements to the hardware and infrastructure world.
{% endblockquote %}

Terraform is an IAC tool that takes care of provisioning an Infrastructure.  Provisioning in layman's terms means to `bring infrastructure resources to life`.  Terraform uses a [declarative programming paradigm](https://en.wikipedia.org/wiki/Declarative_programming) and tracks the state of the resources that you declare using a yaml-like syntax created by Hashicorp (this is the company that created Terraform) called:  HCL (Hashicorp Configuration Language).  The interesting aspect here is that as a user of Terraform you don't need to track the `HOW` to arrive to a specific state, you just have to worry about the `WHAT`, terraform does the rest, it basically takes care of understanding the differences between an infrastructure's current state and the most recent state that it recorded, does a diff between both and figures out the most optimal path to arrive to the new desired state.  The terraform command that modifies your infrastructure reads its current state of the infrastructure, reads the real state of the infrastructure and figures out what changes are required in the real infrastructure to arrived to the desired state.  Note that a key element of terraform is a CLI tool that supports multiple commands to query your infrastructure, modify it, calculate the differences between the terraform state and the infrastructure state, represent a visual representation of the terraform state, etc.   
There are 3 main pieces in the terraform equation:  
1. current known terraform state
2. new desired state 
3. actual infrastructure state.  
Terraform's typical lifecycle will compare these 3 states and identify the required changes to achieve the new desired state.  These changes can be of 3 types:  Create, Add, or Modify a resource(s).  A key notion to consider is that of drift which is the deviation of your infrastructure state from the one that Terraform is tracking.  Drift can happen for example when a user modifies a resource outside of terraform using a UI (e.g the AWS console).  Terraform does its best to deal with drift so as part of its flow it identifies changes between the known and desired terraform state and the real infrastructure state and decides on the actions to take.  Note that from terraform's point of view it's end goal is the desired state, so it will identify any actions required to bring the infrastructure to the desired state.  This means that modifications that took place outside of terraform can be lost if they're not specified in the desired state.        

Now that we have a clear definition of the tool that we intend to use let's establish the high level requirements of the problem that we intend to solve for this article:
- We want create a public website for a personal blog 
- The blog should support articles to be written in [markdown language](https://en.wikipedia.org/wiki/Markdown) to facilite creation and edition of content to people without a strong html+css+javascript background 
- The blog should be as cheap as possible to run and maintain (by cheap I mean less than $5 CAD/month)
- The blog should support templates to render content consistently across different blog posts and blog pages
- The blog should start simple, just as a reading platform but allow to evolve with new features such as comments, comment approvals, etc.
- The blog should support a staging environment where correct display and rendering can be tested and shared without being accessible by the general public
- The blog content should be accesible using https
- The blog response times should be fast and scale automatically whenever there's more viewers
- The blog should support proper rendering in different screen sizes ideally with availability of templates that use responsive design

The chosen technology stack for the solution is:
- IAC Provisioning tool:  Terraform
- Blogging platform:  [Hexo](https://hexo.io/)
- Hosting platform for the blogging website:  AWS S3
- CDN for the blogging website:  AWS Cloudfront
Note:  The goal of this article isn't to justify or explain the rationale behind the chosen technology stack, there are other great tools to manage blogs or to publish static websites out there and I don't have anything against them (Wordpress, Jekyll, etc.).

All of the code used for this article is available in the following github repository:  https://github.com/jorgeandresvasquez/personal-blog.

For the visually inclined (like myself!) here is a diagram of the infrastructure:

{% asset_img JorgePersonalBlogAWSArchitecture.png AWS Personal Blog Architecture %}

The solution has 2 main parts:
1. The infrastructure provisioning
2. The content of the static bloggin website that will run in the AWS infrastructure

This article focuses more on the infrastructure provisioning, however I added some relevant links to the blogging tool (Hexo) at the end 

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

For this specific use case we will be using one same AWS account with 2 stages:  staging and production.  A preferable approach for enterprise environments is to have different AWS accounts, one for each stage or at least 2 of them:  one for production and another one for non-production.  The rationale in this separation is to have complete isolation between environments to prevent accidents and have separation of roles and permissions for the DevOps teams. 

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
- Create a curated library of terraform modules that can be used across your organization.  Here, I tend to focus more on modules that solve common business cases present across the organization:  Example:  Creating a static website infrastructure, creating a DB cluster that is Highly Available and has Optimal Performance, Provisioning a VPC with different private subnets and public subnets that reflect common networking patterns used in your organization (ex:  public Load Balancers + private Application Servers + private RDS Datasources)
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
- After you start using Terraform, you should only use Terraform to manage your IAC.
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
- Use consistent naming conventions for your resources.  The naming conventions can change according to the resource but at least try to include the namespace and stage consistently in there, this way whoever looks at a resource can immediately tell where is it being used.    

## Recommended Naming Conventions

## References
[1]: [Best Coding Practices](https://en.wikipedia.org/wiki/Best_coding_practices)
[2]: [Similar article on starting a blog using hexo and S3] https://dizzy.zone/2017/11/30/Starting-a-blog-with-hexo-and-AWS-S3/
[3]: [Terraform Up and Running Book](https://www.terraformupandrunning.com/)
[4]: [Hexo](https://hexo.io/)
[4]: [Top quality Terraform modules](https://github.com/cloudposse/)
    - https://github.com/cloudposse/terraform-aws-s3-website
    - https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn
[4]: [Terraform official Registry](https://registry.terraform.io/)
[4]: [Good intro guide to Hexo](https://xiaoxing.us/2017/11/18/from-0-to-1-build-your-blog-using-hexo/)
[5]: [Theme chosen for the blog content in Hexo](https://github.com/ppoffice/hexo-theme-icarus)

Finally, here goes my curated list on favorite articles, books, and videos on terraform:

    - Official Terraform Docs
        - https://www.terraform.io/intro/index.html
    - Terraform step by step learning guide from Hashicorp
        - https://learn.hashicorp.com/terraform#getting-started
    - Terraform up and running 2nd edition
        - https://www.terraformupandrunning.com/
    - Why we use Terraform and not Chef, Puppet, Ansible, SaltStack, or CloudFormation
        - https://blog.gruntwork.io/why-we-use-terraform-and-not-chef-puppet-ansible-saltstack-or-cloudformation-7989dad2865c
    - An Introduction to Terraform
        - https://blog.gruntwork.io/an-introduction-to-terraform-f17df9c6d180
    - How to manage Terraform state
        - https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa
    - How to create reusable infrastructure with Terraform modules
        - https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d
    - Terraform tips & tricks: loops, if-statements, and gotchas
        - https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
    - How to keep your Terraform code DRY and maintainable:
        - https://blog.gruntwork.io/terragrunt-how-to-keep-your-terraform-code-dry-and-maintainable-f61ae06959d8
    - How to use Terraform as a team
        - https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973
    - Installing Multiple Versions of Terraform with Homebrew
        - https://blog.gruntwork.io/installing-multiple-versions-of-terraform-with-homebrew-899f6d124ff9
    - Real world experience and proven best practices for terraform
        - https://www.hashicorp.com/resources/terraforming-real-world-experience-best-practices
    - 5 Lessons Learned From Writing Over 300,000 Lines of Infrastructure Code (Excelent!!!!)
        - https://www.youtube.com/watch?v=RTEgE2lcyk4
    - Terragrunt: how to keep your Terraform code DRY and maintainable
        - https://blog.gruntwork.io/terragrunt-how-to-keep-your-terraform-code-dry-and-maintainable-f61ae06959d8
    - Open sourcing Terratest: a swiss army knife for testing infrastructure code
        - https://blog.gruntwork.io/open-sourcing-terratest-a-swiss-army-knife-for-testing-infrastructure-code-5d883336fcd5

_Special kudos to GruntWork, they're doing an amazing job with devops in all aspects, with blog posts, books, open source tools, etc.,  One of the founders of the company:  **Yevgeniy Brikman** is IMO the community rockstar of Terraform!_


