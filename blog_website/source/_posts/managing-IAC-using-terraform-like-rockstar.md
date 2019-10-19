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
Getting started with technologies these days is easier than ever since there are plenty of introductory articles and most technology providers will keep dedicated teams for writing and keeping up-to-date technical documentation with titles such as `Getting started with xxxx`. `10 minute intro to xxxxx`, `Quick intro to...`, etc.  Terraform is no exception to this and they have great entry level documentation here:  
- [Intro to Terraform](https://www.terraform.io/intro/index.html).
- [Getting started with Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html).

Although the Terraform documentation is top quality after reading it you still feel like you're just grasping the surface (as most hello worlds do) and there's lots of complex, enterprise-level scenarios that are still unclear.
People have different learning styles, for me my preference is learning lessons by a mix of theory and examples (I am a big fan of all books finishing by `...in Action`).  

This article will be the first of a series of articles using different use cases that expose best practices within Terraform by example and will progress in complexity from one use case to another.  The first use case that will be covered is the definition of a blog site using serverless technologies in AWS.
My goal is to answer the following questions by the end of this article:
1. How do we define modules that are reusable by a team in Terraform?
2. How do we separate the IAC (Infrastructure as Code) between different environments while achieving [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)?
    It is worth noting that IAC is after all code and the best coding practices that have been refined over the years for software systems are also applicable to IAC. [References](#ref1) 

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
1. The content of the static blogging website that will run in the AWS infrastructure

## Terraform Folder Structure

This article focuses only on the infrastructure provisioning, however I added some relevant links to the blogging tool (Hexo) at the end of this article (Hexo Resources).

| Cloud Folder Structure Before  | Cloud Folder Structure After          |
| :-------------:           |:-------------:                  |
| {% asset_img terraformPersonalBlogFolderStructureModuleStabilization.png AWS Personal Blog Architecture %}               | {% asset_img terraformPersonalBlogFolderStructureFinal.png AWS Personal Blog Architecture %}  |

One key aspect before starting writing terraform code is to define the folder structure for it inside of your VCS [References](#ref3) (In our case we're using git and github).  For my projects I like breaking them by product in a monorepo and inside that monorepo [References](#ref2) I have a folder named:  `cloud`.  It helps me a lot when my folder structure clearly maps to my cloud tooling, environments and modules.  This folder is where I put all the IAC related to provisioning.  Inside cloud there's a subfolder for terraform...providers...aws.  Note that a product can have multiple providers (not too common but possible), but in this case we only have aws.  Under aws I like to separate my resources at a high level by the ones that are global (by global I mean shared across all stages or environments) and the ones that are specific to each environment.  Sometimes the notion of fully global resources may not be present, for example if your company has a completely different AWS account for each environment.  (This is a subject for another discussion altogether but in enterprise systems I highly recommend you to use at least 2 different AWS accounts:  one for production and another one for non-prod).  
In this case since this is a personal blog I decided to only use one AWS account and therefore under global I am keeping the terraform remote backend which is comprised of the S3 bucket that stores my terraform state as well as the dynamodb table to prevent multiple users from modifying the terraform state at the same time (Via terraform state locking).  
For the stages notice that I only have 2 for this specific project:  prod and staging.  It is very common practice to have slight differences in environments.  For example, if you need an AWS RDS Cluster with an instances class of `db.r5.24xlarge` which costs around $11.52/hour you probably want to use something smaller and cheapar than that for your dev environments).  Also, there can be resources that you probably don't require at all in a specific environment.  For example, in this case I purposedly decided to use a CDN with AWS Cloudfront for the prod version of my blog but for the staging version I decided to use directly an S3 bucket where I can verify the rendering of my blog before pushing everything to prod.  
One last and very important folder level by environment is a specific terraform layer/aspect (I still don't have a great word for this).  Let's say that my blog starts becoming more complex and eventually I decide to introduce a relational database to support comments in my blog posts.  In this case I would create another folder for the networking layer of my product and another folder for the database layer of my product.  The reasoning behind this is to be able to separate the different states of different layers of a product to avoid unnecessary risks when modifying infrastructure.

Our folder structure for this scenario would be something as follows:

- prod
 - blog-website
 - relational-db
 - vpc
- staging
 - blog-website
 - relational-db
 - vpc

I believe that we can all agree that the change frequency of your vpc and relational-db will probably be much less than that of your blog-website so instead of modifying a centralized terraform state it is better to just modify the terraform state associated to the layer of your product that changes.  
Also notice that in the folder structure screens at the top there are 2 columns with 2 images:  one representing the folder structure before and the other one after.  This is a personal preference but I have found that creating a stable terraform module requires some practice and iterations to get it right so my preference here is to set it up in the context of a specific application in a modules folder, iterate it and get it stable and once it is then move it to either its own repository or a repository with all the shared modules of an organization.  I know that some people might not agree with me but in my background as a developer it takes me a while to abstract a module correctly and I prefer doing that in isolatio because as Werner Vogels, CTO of Amazon Web Services, says: _"Code can change but APIs are Forever"_ and once a module gets pusblished and starts being used by different systems it is no longer a good idea to do heavy refactoring on it.  

## Steps to Create the AWS cloud environment for my blog website

The following were all the steps that I followed in order to create the infrastructure to host my blogging website in AWS.  You can follow similar steps and use a similar structure to the one I setup in github and you should be able to have a very similar blogging website in no time.    

### Part 1:  Create Global Resources

1.  Setup credentials for AWS and variables for Terraform

    ``` bash
    $ export AWS_ACCESS_KEY_ID=(your access key id)
    $ export AWS_SECRET_ACCESS_KEY=(your secret access key)
    $ export TF_VAR_db_password="(YOUR_DB_PASSWORD)"
    ```
1.  Set the variable names for the global S3 bucket to store the terraform state and the dynamodb table for the locks in file:  `global/s3/variables.tf`

1.  Create the global Terraform resources in AWS using local state file:

    ``` bash
    $ cd cloud/terraform/providers/aws/global
    $ terraform init
    $ terraform apply
    ```

    For this specific use case we will be using one same AWS account with 2 stages:  staging and production.  A preferable approach for enterprise environments is to have different AWS accounts, one for each stage or at least 2 of them:  one for production and another one for non-production.  The rationale in this separation is to have complete isolation between environments to prevent accidents and have separation of roles and permissions for the DevOps teams. 

1.  Add the following section to the file:  `global/main.tf`

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

1. Move the local state file to a remote backend:

    ``` bash
    $ cd global
    $ terraform init
    ```
 
### Part 2:  Create Environment-specific resources
1.  Purchase a cool domain name for your blogging website.  This is a manual 

1.  Provision an SSL Certiifcate within AWS using their Certificate Manager service (ACM).

    In my case I wanted all combinations of access to my blog site to be encrypted, therefore as domain name I used:  `*.thepragmaticloud.com` (www.thepragmaticloud.com, prod.thepragmaticloud.com, etc.). 
    Be mindful that if you also wish to support the apex domain (Example:  `thepragmaticloud.com`) you will need to include a separate domain name for this when requesting the certificate.  (See:  https://docs.aws.amazon.com/acm/latest/userguide/acm-certificate.html)  
    Also, if you have purchased your domain name via route53 in AWS then the best and easiest validation option to choose is:  `DNS validation`
    Note that it usually takes around 5 minutes to issue and validate the certificate on the AWS side but they tell you that this can take up to 30 min.
    Also there's a fundamental requirement of cloudfront, which is that the certificate has to be requeuested in the `us-east-1` region (N. Virginia):

    {% blockquote %}
    To use an ACM Certificate with Amazon CloudFront, you must request or import the certificate in the US East (N. Virginia) region. ACM Certificates in this region that are associated with a CloudFront distribution are distributed to all the geographic locations configured for that distribution.
    {% endblockquote %}

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

## References
1. [Best Coding Practices](https://en.wikipedia.org/wiki/Best_coding_practices) <a name="ref1"></a>
1. [MonoRepos are Awesome!](https://en.wikipedia.org/wiki/Monorepo) <a name="ref2"></a>
1. [Version Control Systems](https://en.wikipedia.org/wiki/Version_control) <a name="ref2"></a>
[2]: [Similar article on starting a blog using hexo and S3] https://dizzy.zone/2017/11/30/Starting-a-blog-with-hexo-and-AWS-S3/
[3]: [Terraform Up and Running Book](https://www.terraformupandrunning.com/)
[4]: [Hexo](https://hexo.io/)
[4]: [Top quality Terraform modules](https://github.com/cloudposse/)
    - https://github.com/cloudposse/terraform-aws-s3-website
    - https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn
[4]: [Terraform official Registry](https://registry.terraform.io/)
[4]: [Good intro guide to Hexo](https://xiaoxing.us/2017/11/18/from-0-to-1-build-your-blog-using-hexo/)
[5]: [Theme chosen for the blog content in Hexo](https://github.com/ppoffice/hexo-theme-icarus)

## Curated list of terraform online learning resources
{% blockquote %}
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
{% endblockquote %}

## Hexo Resources
The typical workflow to experiment locally with hexo involves the following steps:
1. Install the hexo cli

{% blockquote %}
- Hexo Official docs
    - https://hexo.io/docs/
- Icarus theme chosen for my personal blog content in Hexo
    - https://github.com/ppoffice/hexo-theme-icarus
    - https://blog.zhangruipeng.me/hexo-theme-icarus/
- Concise and good intro guide to hexo:
    - https://xiaoxing.us/2017/11/18/from-0-to-1-build-your-blog-using-hexo/
- Mike Dane's (from Giraffe Academy's) video guides to Hexo:
    - https://www.mikedane.com/static-site-generators/hexo/
{% endblockquote %}

_Special kudos to Hashicorp for creating Terraform and for open sourcing it and creating an awesome community around it, you guys ruck! And to GruntWork for doing an amazing job with devops in all aspects, with blog posts, books, open source tools, etc.,  One of the founders of the company:  **Yevgeniy Brikman** is IMO the community rockstar of Terraform!_


