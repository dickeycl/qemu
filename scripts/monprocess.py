#!/usr/bin/python3

import re
import sys

trace_pat = re.compile("^\d+@(\d+\.\d+):([a-zA-Z0-9_]+)( (.*))?$")
ram_pages_saved_pat = re.compile("saved (\d+) pages")
savevm_section_start_pat = re.compile("([^,]+), section_id (\d+)")
savevm_section_end_pat = re.compile("(\s+), section_id (\d+) -> (-?\d+)")

pages = 0
for line in map(str.rstrip, sys.stdin):
    m = trace_pat.match(line)
    if m:
        time = float(m[1])
        trace = m[2]
        message = m[4]
        if trace == 'savevm_section_start':
            m2 = savevm_section_start_pat.match(message)
            if pages == 0:
                start_time = time
            if m2:
                if m2[1] != 'ram':
                    ram_time = time
            else:
                print("unparsable {} message {}".format(trace, message))
        elif trace == 'savevm_section_end':
            last_section_time = time
        elif trace == 'ram_pages_saved':
            m2 = ram_pages_saved_pat.match(message)
            pages = int(m2[1])
        elif trace == 'qemu_file_fclose':
            print("ram {} pages {:.4g} sec, VM {:.4g} sec, flush {:.4g} sec".format(pages, ram_time - start_time, last_section_time - ram_time, time - last_section_time))
            pages = 0
        else:
            pass # a trace line, but not one of interest
    else:
        pass # ignore all non-trace lines
