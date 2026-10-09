"""Read-only class reference parser, shared implementation with the Ghast tooling."""
import struct

def class_reference(data):
    """Small class-file reader: records bytecode + resolved constants, not a decompiler."""
    cursor = 8

    def read(fmt):
        nonlocal cursor
        value = struct.unpack_from('>' + fmt, data, cursor)
        cursor += struct.calcsize('>' + fmt)
        return value[0] if len(value) == 1 else value

    pool = {}
    count = read('H')
    index = 1
    while index < count:
        tag = read('B')
        if tag == 1:
            length = read('H')
            value = data[cursor:cursor + length].decode('utf-8', errors='replace')
            cursor += length
        elif tag in (3, 4, 5, 6):
            value = read({3: 'i', 4: 'f', 5: 'q', 6: 'd'}[tag])
        elif tag in (7, 8, 16, 19, 20):
            value = read('H')
        elif tag in (9, 10, 11, 12, 17, 18):
            value = read('HH')
        elif tag == 15:
            value = read('BH')
        else:
            raise ValueError(f'Unknown constant pool tag {tag}')
        pool[index] = (tag, value)
        index += 2 if tag in (5, 6) else 1

    def resolve(index):
        tag, value = pool[index]
        if tag in (7, 8, 16, 19, 20):
            return resolve(value)
        if tag in (9, 10, 11, 12):
            return ' '.join(str(resolve(v)) for v in value)
        return value

    read('HHH')
    for _ in range(read('H')):
        read('H')

    def members():
        nonlocal cursor
        result = []
        for _ in range(read('H')):
            flags, name, descriptor = read('HHH')
            member = {'name': resolve(name), 'descriptor': resolve(descriptor)}
            for _ in range(read('H')):
                attribute = resolve(read('H'))
                length = read('I')
                start = cursor
                if attribute == 'Code':
                    read('HH')
                    code_length = read('I')
                    member['bytecode_hex'] = data[cursor:cursor + code_length].hex(' ')
                cursor = start + length
            result.append(member)
        return result

    members()  # fields
    methods = members()
    return {'constants': {str(k): resolve(k) for k in pool}, 'methods': methods}
