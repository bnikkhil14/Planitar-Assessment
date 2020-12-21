#!/usr/bin/env python3
#Author:Nikhil

from os import path, walk
from sys import argv
import fnmatch

data = []
if len(argv) < 2:
    print("Usage ./02-parent-images.py .")
relative_path = path.abspath(argv[1])
matches = []
for root, dirs, files in walk(relative_path):
    for filename in fnmatch.filter(files, 'Dockerfile'):
        matches.append(path.join(root, filename))

for file in matches:
    with open(file, 'r') as f:
        filedata = f.readlines()
    for line in filedata:
        if line.startswith('FROM'):
            data.append('{0}: {1}'.format(file, line))
print(''.join(data))


