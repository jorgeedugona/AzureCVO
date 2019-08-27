##############################
# Name of the Resource Group #
##############################
$ResourceGroupName = 'NetApp-RG-vdbench'

############
# Location #
############
$Location = 'UK South'

######################################
# Max Number of Linux (Slaves is 10) #
######################################
$NumberLinuxVMs = 1

########################
# Volume size is in GB #
########################
[string]$FileSize = 1

#########################################################
# Volume size is in GB, It must be bigger than Filesize #
#########################################################
[string]$VolumeSize = 20

##################################
# Number of Volumes per Linux VM #
##################################
$NumberVolumesPerVM = 6 ## It must be an even number as there are two aggregates. 
