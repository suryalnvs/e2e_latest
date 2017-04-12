#!/usr/bin/python2.7
import shlex
import sys
import subprocess
import xmlrunner
import unittest
from subprocess import Popen, PIPE
from xmlrunner import XMLTestRunner
class TestExample02(unittest.TestCase):

    def runIt(self, command):
        cmd = "./scripts/script.sh %s %s %s %s %s"% (CHANNEL_NAME, CHANNELS, CHAINCODES, ENDORSERS, command)
        #print cmd
        p = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
        output = p.communicate()[0]
        #print output
        self.assertEqual(p.returncode, 0)

    def test_aCreateChannel(self):
        self.runIt("create")

    def test_bJoinChannel(self):
        self.runIt("join")

    def test_cInstall(self):
        self.runIt("install")

    def test_dInstantiate(self):
        self.runIt("instantiate")

    def test_eInvokeQuery(self):
        self.runIt("invokeQuery")
    
if __name__ == '__main__':
    CHANNEL_NAME = sys.argv[1]
    CHANNELS = sys.argv[2]
    CHAINCODES = sys.argv[3]
    ENDORSERS = sys.argv[4]
    sys.argv.pop()
    sys.argv.pop()
    sys.argv.pop()
    sys.argv.pop()
    print CHANNEL_NAME
    print CHANNELS
    print CHAINCODES
    print ENDORSERS
    #suite = unittest.TestLoader().loadTestsFromTestCase(TestExample02)
    #unittest.TextTestRunner(verbosity=2, xmlrunner.XMLTestRunner(output='test-reports')).run(suite)
    unittest.main(verbosity=2, testRunner=xmlrunner.XMLTestRunner(output='test-reports'))
