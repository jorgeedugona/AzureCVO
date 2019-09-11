##############################
# Name of the Resource Group #
##############################
$ResourceGroupName = 'NetApp-RG-vdbench'

#########################
# Azure Region/Location #
#########################
$Location = 'UK South'

##############################################
# Number of Linux Workers (Max number is 10) #
##############################################
$NumberLinuxVMs = 2

######################
# File Size is in GB #
######################
[string]$FileSize = 1

############################################################
# Volume size is in GB, It must be 10 bigger than Filesize #
############################################################
[string]$VolumeSize = 20

#########################################
# Number of Volumes per Linux Worker VM #
#########################################
###########################################################################
## Important Note: It must be an even number as there are two aggregates ##
###########################################################################
$NumberVolumesPerVM = 6 
 