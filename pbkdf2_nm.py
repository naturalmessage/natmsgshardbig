# pbkdf2_nm.py


################################################################################
# Copyright 2015 Natural Message, LLC.
# Author: Robert Hoot (naturalmessage@fastmail.fm)
#
# This file is part of the Natural Message Shard Server.
#
# The Natural Message Shard Server is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Natural Message Shard Server is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natural Message Shard Server.  If not, see <http://www.gnu.org/licenses/>.
################################################################################
#
# This is a system for prompting the user to enter a 
# password, then strengthening that password with
# PBKDF2.  The intent is to use the hashed password
# to encrypt shards on shard servers.

# This will generate the PBKDF2 hashed password that will
# be used in "encryption format 1" for the shard servers.
# This process allows me to generate a complex password (once)
# so that when the shard-encryption process runs, I just
# use the pre-hashed password on all of the encrypted shards.
# 

import hmac
import hashlib
from Crypto.Protocol import KDF

import base64
import getpass
import os

##def pw_hash(iterations=571373, verify_fname='natmsg_pw_receipt.save'):
## Once you save a shard with a given iteration value
## you can not change the iteration value without causing
## decrypt errors on all the old shards.
def pw_hash(iterations=97831, verify_fname='natmsg_pw_receipt.save'):
	# the user is prompted to enter a password, then it is hashed
	receipt = None
	pw_hashed = None
	def main_loop():
		pw_hashed = None
		pw = ''
		print('If you forget the password, all shards that are stored on your')
		print('server will be lost forever.')
		while pw == '':
			try:
				pw = getpass.getpass('Enter the password for Natural ' \
					+ 'Message shard encryption: ')
			except KeyboardInterrupt:
				print() # move to a new output line
				return(None)

		# The salt is set to zero so that I get the same
		# output every time that I run this because I will
		# use the output here as the password later.
		# This routine is based on the one in RNCryptor (with 
		# the salt modified):
		print('Please wait while the password is being hashed.')
		print('You will be prompted to verify the results...')
		pw_hashed = KDF.PBKDF2(pw, b'00', dkLen=32, count=iterations,
		prf=lambda p, s: hmac.new(p, s, hashlib.sha256).digest())

		return pw_hashed
		# end of main_loop
		# --------------------------------------------

	yn = 'n'
	while yn.lower() not in ('y', 'yes', 'q', 'quit'):
		pw_hashed = main_loop()
		if pw_hashed is not None:
			receipt = base64.b64encode(pw_hashed[0:10]).decode('utf-8')
			yn = 'x'
			while yn.lower() not in ('y', 'n', 'yes', 'no', 'q', 'quit'):
				print('Your receipt is: ' + receipt)
				try:
					yn = input('Do you want to keep this password? (y/n/q)?')
				except KeyboardInterrupt:
					print() # move to a new output line
					yn = 'x'

			if yn.lower() in ('q', 'quit'):
				pw_hashed = None
				receipt = None
				break
		else:
			print() # move to a new output line
			yn4 = input('Do you want to quit (y/n)?: ')
			if yn4 in ('y', 'yes'):
				break
			
	if os.path.isfile(verify_fname):
		# Verify that the receipt is the same as the saved copy
		with open(verify_fname, 'r') as fd:
			saved_rcpt = fd.read()

		if receipt is not None:
			if saved_rcpt != receipt:
				print('BAD pw')
				pw_hashed = None
			else:
				print('GOOD pw')
	
		else:
			# Probably redundant
			print('missing receipt')
			pw_hashed = None
	
	else:
		print()
		print()
		print('============ WARNING!!! ================')
		print('There was no prior verification file.')
		print('If you have already run the Natural Message server')
		print('with a password, you can ruin all shards by entering')
		print('the wrong password.')
		print('If you are starting the server for the first time')
		print('or if you are intentionally resetting the password,')
		print('then proceed, else enter "n" to quit.')
		print(' ')
		yn2 = 'x'
		while yn2.lower() not in ('y', 'n', 'yes', 'no'):
			try:
				yn2 = input('Do you want to create a new password receipt (y/n)?: ')
			except KeyboardInterrupt:
				yn = 'x'

		if yn2.lower() in ('y' 'yes'):
			with  open(verify_fname, 'w') as fd:
				fd.write(receipt)

			print('')
			print('Press any key to enter the password again to verify')
			print('your initial password.')
			junk = input('...')
			pw_hash(iterations, verify_fname)
		else:
			# The user does not want to write to the receipt file.
			# It sounds like the user might need to recover the
			# receipt file or maybe run again to get the password
			# right to save the correct pw.
			# user can enter the correct password or quit.
			pw_hashed = None
			
	return(pw_hashed)

