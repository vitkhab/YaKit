#!/usr/bin/env python
'''
New versions of this script will be available at
https://github.com/KrylCW/YaKit/tree/master/2014/exam00/task01

Due deadline I couldn't program everything I wanted
I ask you to look for newer version of this script at the link above

This script works only with one failed raid and processes next situations:
 * If there is faulty partition in any raid, script removes this disk's partitions from all
   raids and adds suitable partitions from spare disk
 * If there is one missing partition in the raid, script adds corresponding partition from
   spare disk
'''
import subprocess
import re


def get_disks():
    disks = []
    lsblk = str(subprocess.check_output(['lsblk']))

    for line in lsblk.split('\n'):
        found = re.search('(.*?)[ \t]+.*disk', line)
        if found:
            disks.append(found.group(1))
    return disks


def get_raids():
    raids = {}
    mdstat = subprocess.check_output(['cat', '/proc/mdstat'])
    for line in mdstat.split('\n'):
        found = re.search('(.*)[ \t]+:.*raid1[ \t]+(.*)', line)
        if found:
            raids[found.group(1)] = found.group(2).split(' ')
    return raids


def find_spare_disk():
    sparedisks = []
    disks = get_disks();
    raids = get_raids();

    for disk in disks:
        found = False
        for ra in raids:
            for element in raids[ra]:
                if element.find(disk) >= 0:
                    found = True
        if not found:
            sparedisks.append(disk)
    if len(sparedisks) > 0:
        print "Found %d disks, using %s" % (len(sparedisks), sparedisks[0])
        return sparedisks[0]
    return None


def find_failed_raid():
    activeraid = ''
    failedraids= []
    probable_fail = False
    mdstat = subprocess.check_output(['cat', '/proc/mdstat'])

    for line in mdstat.split('\n'):
        found = re.search('(.*)[ \t]+:.*raid[0-9]+[ \t]+(.*)', line)
        if found:
            activeraid = found.group(1)
        elif probable_fail:
            if line.find('recovery') < 0 and activeraid not in failedraids:
                failedraids.append(activeraid)
            probable_fail = False
        elif activeraid:
            status = re.search('.*blocks.*\[([0-9]+)\/([0-9]+)\]', line)
            if status:
                if status.group(1) > status.group(2):
                    probable_fail = True
    if len(failedraids) > 0:
        return failedraids[0]
    return None


def find_faulty_disk():
    faultydisks = []
    raids = get_raids()
    disks = get_disks()
    for ra in raids:
        for element in raids[ra]:
            found = re.search('(F)', element)
            if found:
                for disk in disks:
                    if element.find(disk) >= 0 and disk not in faultydisks:
                        faultydisks.append(disk)
    if len(faultydisks) > 0:
        return faultydisks[0]
    return None


def find_clean_disk():
    cleandisks = []
    raids = get_raids()
    disks = get_disks()
    faultyraid = find_failed_raid()
    faultydisk = find_faulty_disk()
    for element in raids[faultyraid]:
        if faultydisk == None or element.find(faultydisk) < 0:
            for disk in disks:
                if element.find(disk) >= 0:
                    cleandisks.append(disk)
    if len(cleandisks) > 0:
        return cleandisks[0]
    return None


def copy_partition_table():
    cleandisk = find_clean_disk()
    sparedisk = find_spare_disk()
    get_partition_table = subprocess.Popen(['sfdisk', '-d', '/dev/'+cleandisk], stdout=subprocess.PIPE)
    try:
        subprocess.check_output(['sfdisk', '/dev/'+sparedisk], stdin=get_partition_table.stdout)
    except subprocess.CalledProcessError:
        print "No partition table was found"


def rebuild_raids():
    raids = get_raids()
    cleandisk = find_clean_disk()
    sparedisk = find_spare_disk()
    faultyraid = find_failed_raid()
    faultydisk = find_faulty_disk()
    for ra in raids:
        for element in raids[ra]:
            if element.find(cleandisk) >= 0:
                partition = re.search(cleandisk + '([0-9]*)', element).group(1)
                if faultydisk:
                    subprocess.check_output(['mdadm', '--fail', '/dev/'+ra, '/dev/'+faultydisk+partition])
                    subprocess.check_output(['mdadm', '--remove', '/dev/'+ra, '/dev/'+faultydisk+partition])
                    subprocess.check_output(['mdadm', '--manage', '/dev/'+ra, '--add', '/dev/'+sparedisk+partition])
                elif ra == faultyraid:
                    subprocess.check_output(['mdadm', '--manage', '/dev/'+ra, '--add', '/dev/'+sparedisk+partition])

if find_failed_raid():
    copy_partition_table()
    rebuild_raids()