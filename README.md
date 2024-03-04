# CYDERES Telemetry Skills Challenge

This repository serves as my completion of the CYDERES Telemetry Skills challenge as outlined by the TelEng_Skills_Challenge.docx in the extra folder.

### Overview

This project covers:

- Installation of ELK Stack on bare metal Kubernetes.
- Overview of technical choices regarding Logstash.
- Testing and Troubleshooting.
- The Solution
- Things to do

## Installation of ELK Stack on Bare Metal Kubernetes

While the instructions for this challenge suggested installing Logstash on a virtual machine or physical machine, I had neither at my disposal. My personal laptop runs Qubes OS, which is best described as an end-user hypervisor. The homelab consists of two microcomputers and an old laptop configured as a three-node Kubernetes cluster. Not wanting to install more on these nodes outside of Kubernetes tools, I opted to deploy the ELK stack on it, as this is supported and would not be contradictory to the spirit of this exercise. The installation was somewhat finicky, with issues such as core DNS not resolving short names and forgetting to label the Logstash pod. Helm was used to install the Elasticsearch cluster and the NFS client provisioner. Everything concerning the ELK stack was deployed in the elastic-systems namespace. This deployment works well as an example, but it is nowhere near production-ready. Sensitive data like passwords or hostnames have been removed. There is also an issue with the certificate on the Elasticsearch cluster where I have to ignore validity, and there are not yet any network rules to secure traffic. Config maps were used to bind the pipelines and patterns directories to the Logstash pod for its configuration.


## Overview of Technical Choices Regarding Logstash

For Logstash, I decided to break up the configuration files out of the main Logstash deployment YAML file as it would have become unruly. Inside the pipelines directory, I have 01-inputs.yaml, 10-pfsense.conf, 11-cyderes-challenge.conf, and 30-output.conf. For inputs, I made one specifically for this challenge, one for my pfSense firewall, and another for Linux hosts to send to after they've had Filebeat installed and configured using Ansible. For 11-cyderes-challenge.conf, I used mutate, grok, and ruby to format and parse the test data sent in the challenge doc. For the output, as I was using the ELK Stack, I configured this to point toward the Elasticsearch Kubernetes service.


## Testing and Troubleshooting

This was an interesting challenge. When Logstash was started, and I checked Kibana to see if the logs were coming through after running the following command within the grok-chaos directory:

```cat test.txt | nc -u dev-kube-worker03.home.local 30142```

I saw that the grok match function was not working. The logs were coming in but weren't getting parsed correctly. I then opened up Kibana's grok debugger and began building the match rule very carefully. I noticed that while the command looked correct, it was not matching whitespace. I went back to the original challenge doc and noticed that I thought there were some display errors as I used LibreOffice to open a .docx file, and some of the whitespaces had not displayed properly because of this. I realized this was probably impeding the filter. I used a sed command to clean up the nonstandard whitespaces and was then able to get the grok parser to match as intended.

After pondering on this for some time, I considered that perhaps, since the doc had many of these non-standard whitespaces, this could have been some kind of oversight. However, as it threw me for such a loop, and seemed completely possible, albeit completely ill-advised, that some devices could potentially send logs into Logstash in such a way, and that this too might also be part of the challenge.


### The Solution

The first thing I had to do was understand more about these white spaces. To do this, you can run the following and get this output:
```
od -An -c -t u1 test.txt

   <   1   4   >   1   	2   0   1   6   -   1   2   -   2   5
  60  49  52  62  49  32  50  48  49  54  45  49  50  45  50  53
   T   0   9   :   0   3   :   5   2   .   7   5   4   6   4   6
  84  48  57  58  48  51  58  53  50  46  55  53  52  54  52  54
   -   0   6   :   0   0   	c   o   n   t   o   s   o   h   o
  45  48  54  58  48  48  32  99 111 110 116 111 115 111 104 111
   s   t   1   	a   n   t   i   v   i   r   u   s   	2   4
 115 116  49  32  97 110 116 105 118 105 114 117 115  32  50  52
   9   6   	-   	- 302 240   a   l   e   r   t   n   a   m
  57  54  32  45  32  45 194 160  97 108 101 114 116 110  97 109
   e   =   "   V   i   r   u   s   	F   o   u   n   d   " 302
 101  61  34  86 105 114 117 115  32  70 111 117 110 100  34 194
 240   c   o   m   p   u   t   e   r   n   a   m   e   =   "   c
 160  99 111 109 112 117 116 101 114 110  97 109 101  61  34  99
   o   n   t   o   s   o   p   c   4   2   " 302 240   c   o   m
 111 110 116 111 115 111 112  99  52  50  34 194 160  99 111 109
   p   u   t   e   r   i   p   =   "   2   1   6   .   5   8   .
 112 117 116 101 114 105 112  61  34  50  49  54  46  53  56  46
   1   9   4   .   1   4   2   "   	s   e   v   e   r   i   t
  49  57  52  46  49  52  50  34  32 115 101 118 101 114 105 116
   y   =   "   1   " 302 240  \n
 121  61  34  49  34 194 160  10
```


Using some ChatGPT4, I found that the "194 160" part was, in fact, the culprit. I then set out to remove this from the line before grok processed it. I suppose I could have figured out a way for grok to match said whitespace, but having mutate do this for me with all logs that came in seemed like the best, most robust option. I made this command to take out all kinds of nonstandard whitespaces:


```
mutate {
    # Replace non-standard whitespace characters with a standard space
    gsub => ["message", "[\\u00A0\\u1680\\u2000-\\u200A\\u202F\\u205F\\u3000]", " "]
}
```

With that in place, and a little more tweaking, I was able to send both the cleaned-up and original logs in with the above netcat command and saw that Logstash was able to parse both properly, and it showed no errors, and all fields when viewed via Kibana.

This was a fun experience, and I was able to learn a lot from it!

## Things to do

- Set up RBAC (Role-Based Access Control) for enhanced security and access management in Kubernetes.
- Create network security policies to establish a zero-trust environment and restrict traffic flow between pods.
- Install MetalLB on the cluster and configure it to provide a LoadBalancer service, eliminating the need for node port exposure.
- Create an Ansible playbook to deploy and update Filebeat configurations on home Linux nodes for log collection.
- Dive into Kibana to create and customize dashboards for monitoring and visualizing data from your home lab.
- Implement log rotation and retention policies in Elasticsearch to manage storage and ensure efficient performance.
- Explore the use of Elasticsearch index templates to optimize index settings and mappings for different types of logs.
- Set up alerting in Kibana to notify me of specific events or anomalies in my home lab environment.
- Document the setup and configuration process for future reference and ease of maintenance.
- Set up kustomize or Helm for control versioning and future upgrades. 

