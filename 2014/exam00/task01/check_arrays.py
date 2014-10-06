#!/usr/bin/env python
'''
This script works only with one failed raid and processes next situations:
 * If there is faulty partition in any raid, script removes this disk's partitions from all
   raids and adds suitable partitions from spare disk
 * If there is one missing partition in the raid, script adds corresponding partition from
   spare disk
'''
import subprocess
import re
import time


def get_disks():
    disk = None
    disks = {}
    lsblk = subprocess.check_output(['lsblk'])

    for line in lsblk.split('\n'):
        re_disk = re.search('(.*?)[ \t]+.*disk', line)
        if re_disk:
            disk = re_disk.group(1)
            disks[disk] = []
        elif disk:
            re_raid = re.search('[ \t\|\`\-]*(.*?)[ \t]+.*raid', line)
            if re_raid and re_raid.group(1) not in disks[disk]:
                disks[disk].append(re_raid.group(1))
    return disks


def get_raids():
    raid = None
    raids = {}
    mdstat = subprocess.check_output(['cat', '/proc/mdstat'])

    for line in mdstat.split('\n'):
        found = re.search('(.*)[ \t]+:.*(raid[0-9]+)[ \t]+(.*)', line)
        if found:
            raid = found.group(1)
            if raid not in raids:
                raids[raid] = {}
            raids[raid]['level'] = found.group(2)
            raids[raid]['status'] = 'Clean'
            raids[raid]['spare_disks'] = []
            raids[raid]['active_disks'] = []
            raids[raid]['failed_disks'] = []
            disks = found.group(3).split(' ')
            for disk in disks:
                partition = re.search('(.*)\[[0-9]+\]', disk).group(1)
                if disk.find('(S)') >= 0:
                    raids[raid]['spare_disks'].append(partition)
                elif disk.find('(F)') >= 0:
                    raids[raid]['failed_disks'].append(partition)
                else:
                    raids[raid]['active_disks'].append(partition)
        elif raid:
            if raids[raid]['status'] == 'Probably failing':
                if line.find('recovery') < 0:
                    raids[raid]['status'] = 'Degraded'
                else:
                    raids[raid]['status'] = 'Recovering'
            status = re.search('.*blocks.*\[([0-9]+)\/([0-9]+)\]', line)
            if status:
                raids[raid]['max_disks'] = int(status.group(1))
                raids[raid]['cur_disks'] = int(status.group(2))
                if raids[raid]['max_disks'] > raids[raid]['cur_disks']:
                    raids[raid]['status'] = 'Probably failing'
    return raids


def find_spare_disks(failed_disks = None):
    if failed_disks == None:
        failed_disks = []
    spare_disks = []
    disks = get_disks();

    for disk in disks:
        if len(disks[disk]) == 0 and disk not in failed_disks:
            spare_disks.append(disk)
    return spare_disks


def find_failed_raids():
    failed_raids = []
    raids = get_raids()

    for raid in raids:
        if raids[raid]['status'] == 'Degraded':
            failed_raids.append(raid)
    return failed_raids


def find_faulty_disks(raid):
    raids = get_raids()

    return raids[raid]['failed_disks']


def find_pt_donor(raid):
    raids = get_raids()

    if len(raids[raid]['active_disks']) > 0:
        return raids[raid]['active_disks'][0]
    elif len(raids[raid]['spare_disks']) > 0:
        return raids[raid]['spare_disks'][0]
    return None


def copy_partition_table(source, dest):
    if source == None or dest == None:
        print "No source or dest is specified"
        return None
    get_partition_table = subprocess.Popen([ 'sfdisk', '-d', '/dev/' + source ], stdout=subprocess.PIPE)
    try:
        subprocess.check_output([ 'sfdisk', '/dev/' + dest ], stdin=get_partition_table.stdout)
    except subprocess.CalledProcessError:
        print "No partition table was found"



def add_disk(raid, spare_diskpart):
    subprocess.check_output([ 'mdadm', '--manage', '/dev/' + raid, '--add', '/dev/' + spare_diskpart ])


def remove_disk(raid, removable):
    try:
        subprocess.check_output([ 'mdadm', '--fail', '/dev/' + raid, '/dev/' + removable ])
    except subprocess.CalledProcessError:
        print "Disk already failed"
    subprocess.check_output([ 'mdadm', '--remove', '/dev/' + raid, '/dev/' + removable ])


def remove_failed_disks():
    disks = get_disks()
    raids = get_raids()
    failed_disks = []

    for raid in find_failed_raids():
        for faulty in raids[raid]['failed_disks']:
            faulty_disk = re.search('([A-Za-z]+)([0-9]*)', faulty).group(1)            
            for tmp_raid in disks[faulty_disk]:
                tmp_disks = raids[tmp_raid]['active_disks'] + raids[tmp_raid]['spare_disks'] + raids[tmp_raid]['failed_disks']
                for tmp_disk in tmp_disks:
                    if tmp_disk.find(faulty_disk) >= 0:
                        tmp_part = re.search('([A-Za-z]+)([0-9]*)', tmp_disk).group(2)
                        remove_disk(tmp_raid, faulty_disk + tmp_part)
                        failed_disks.append(faulty_disk)
    return failed_disks



def add_spare_disks(failed_disks):
    disks = get_disks()
    raids = get_raids()
    spare_disks = find_spare_disks(failed_disks)

    raid = find_failed_raids()[0]
    if len(spare_disks) == 0:
        print "Sorry, no more spare disk for you"
        exit(1)
    donor = find_pt_donor(raid)
    spare_disk = spare_disks.pop()
    donor_disk = re.search('([A-Za-z]+)([0-9]*)', donor).group(1)
    donor_part = re.search('([A-Za-z]+)([0-9]*)', donor).group(2)
    copy_partition_table(donor_disk, spare_disk)
    for tmp_raid in disks[donor_disk]:
        for tmp_disk in raids[tmp_raid]['active_disks']:
            if tmp_disk.find(donor_disk) >= 0:
                tmp_part = re.search('([A-Za-z]+)([0-9]*)', tmp_disk).group(2)
                add_disk(tmp_raid, spare_disk + tmp_part)
                print 'Add disk %s to array %s' % (spare_disk + tmp_part, tmp_raid)
                time.sleep(5)
                break


def rebuild_raids():
    failed_disks = remove_failed_disks()
    while (len(find_failed_raids()) > 0 and len(find_spare_disks(failed_disks)) > 0):
        add_spare_disks(failed_disks)


rebuild_raids()