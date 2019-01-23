# -*- coding: utf-8 -*-
"""
Normalize orthography: search for and replace words 
"""

import re
import unicodedata
import sys
import argparse
import logging

def process_file(filename, replacer):
    """
    Open 'filename', replace words using the dictionary 'replacement',
    and save to the original filename.
    
    Since this is intended to operate on a git repo, I don't worry
    about accidentally changing a file.
    """
    with open(filename, 'r', encoding='UTF-8') as f:
        read_data = unicodedata.normalize('NFD', f.read())
        re.sub(r'[a-zA-ZáéíóúÁÉÍÓÚæœ́]+', replacer, read_data)

    with open(filename, 'w', encoding='UTF-8') as f:
        f.write(unicodedata.normalize('NFC', read_data))

def make_replacer(the_dict):
    # The lambda will receive a match object as an argument, so it must
    # use group() to get a string.
    return lambda w: w.group(0) if w.group(0) not in the_dict else the_dict[w.group(0)]

def printer(m):
    print(m.group(0))
    return m.group(0)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input', action='append')
    parser.add_argument("-q", "--quiet", dest="quiet_count", action="count", default=0, help="decreases log verbosity for each occurrence.")
    parser.add_argument("-v", "--verbose", dest="verbose_count", action="count", default=0, help="increases log verbosity for each occurrence.")
    parser.add_argument('-w', '--words', help='words and their replacements', action='append', default=[])
    args = parser.parse_args()

    level = max(3 + args.quiet_count - args.verbose_count, 0) * 10
    logging.basicConfig(stream=sys.stderr, level=level)

    replacement = {}
    # Load replacements
    for filename in args.words:
        with open(filename, 'r', encoding='UTF-8') as f:
            lineno = 0
            for line in f:
                line = unicodedata.normalize('NFD', line)
                lineno += 1
                words = line.split()
                if len(words) != 2:
                    if len(words) != 0:
                        logging.warning('{}: line {} contains {} words instead of 2 (skipped).'.format(filename, lineno, len(words)))
                    continue
                replacement[words[0]] = words[1]
    # Make a function that uses the dictionary to replace words
    replacer = make_replacer(replacement)

    # QX: Test replacer
    print(re.sub(r'[a-zA-ZáéíóúÁÉÍÓÚæœ́]+', replacer, 'nunquam fecit obédiens'))

    # Process files
    for filename in args.input:
        process_file(filename, replacer)

if __name__ == "__main__":
    main()
