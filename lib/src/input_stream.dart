import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum ByteOrder {
  little_endian,
  big_endian,
}

abstract class InputStream {
  ///  The current read position relative to the start of the buffer.
  int get position;

  /// How many bytes are left in the stream.
  int get length;

  /// Is the current position at the end of the stream?
  bool get isEOS;

  /// Reset to the beginning of the stream.
  void reset();

  /// Rewind the read head of the stream by the given number of bytes.
  void rewind([int length = 1]);

  /// Move the read position by [count] bytes.
  void skip(int length);

  /// Read a single byte.
  int readByte();

  /// Read [count] bytes from the stream.
  Uint8List readBytes(int count);

  /// Read a null-terminated string, or if [len] is provided, that number of
  /// bytes returned as a string.
  String readString({int size, bool utf8});

  /// Read a 16-bit word from the stream.
  int readUint16();

  /// Read a 32-bit word from the stream.
  int readUint32();

  /// Read a 64-bit word form the stream.
  int readUint64();

  Uint8List toUint8List();
}

/// A buffer that can be read as a stream of bytes
class BytesInputStream extends InputStream {
  Uint8List buffer;
  int offset;
  int start;
  ByteOrder byteOrder;

  /// Create a InputStream for reading from a List<int>
  BytesInputStream(Uint8List data,
      {this.byteOrder = ByteOrder.big_endian, int start = 0, int length})
      : buffer =
            Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
        offset = start,
        start = start {
    _length = length ?? buffer.length;
  }

  ///  The current read position relative to the start of the buffer.
  @override
  int get position => offset - start;

  /// How many bytes are left in the stream.
  @override
  int get length => _length - (offset - start);

  /// Is the current position at the end of the stream?
  @override
  bool get isEOS => offset >= (start + _length);

  /// Reset to the beginning of the stream.
  @override
  void reset() {
    offset = start;
  }

  /// Rewind the read head of the stream by the given number of bytes.
  @override
  void rewind([int length = 1]) {
    offset -= length;
    if (offset < 0) {
      offset = 0;
    }
  }

  /// Access the buffer relative from the current position.
  int operator [](int index) => buffer[offset + index];

  /// Return a InputStream to read a subset of this stream.  It does not
  /// move the read position of this stream.  [position] is specified relative
  /// to the start of the buffer.  If [position] is not specified, the current
  /// read position is used. If [length] is not specified, the remainder of this
  /// stream is used.
  InputStream subset([int position, int length]) {
    if (position == null) {
      position = offset;
    } else {
      position += start;
    }

    if (length == null || length < 0) {
      length = _length - (position - start);
    }

    return BytesInputStream(buffer,
        byteOrder: byteOrder, start: position, length: length);
  }

  /// Returns the position of the given [value] within the buffer, starting
  /// from the current read position with the given [offset].  The position
  /// returned is relative to the start of the buffer, or -1 if the [value]
  /// was not found.
  int indexOf(int value, [int offset = 0]) {
    for (var i = this.offset + offset, end = this.offset + length;
        i < end;
        ++i) {
      if (buffer[i] == value) {
        return i - start;
      }
    }
    return -1;
  }

  /// Move the read position by [count] bytes.
  @override
  void skip(int count) {
    offset += count;
  }

  /// Read a single byte.
  @override
  int readByte() {
    return buffer[offset++];
  }

  /// Read [count] bytes from the stream.
  @override
  Uint8List readBytes(int count) {
    final bytes = subset(offset - start, count);
    offset += bytes.length;
    return bytes.toUint8List();
  }

  /// Read a null-terminated string, or if [len] is provided, that number of
  /// bytes returned as a string.
  @override
  String readString({int size, bool utf8 = true}) {
    final codes = <int>[];
    if (size == null) {
      while (!isEOS) {
        var c = readByte();
        if (!utf8) {
          var c2 = readByte();
          c = (c2 << 8) | c;
        }
        if (c == 0) {
          break;
        }
        codes.add(c);
      }
    } else {
      while (size > 0) {
        var c = readByte();
        size--;
        if (!utf8) {
          var c2 = readByte();
          size--;
          c = (c2 << 8) | c;
        }
        if (c == 0) {
          break;
        }
        codes.add(c);
      }
    }

    return utf8 ? Utf8Decoder().convert(codes) : String.fromCharCodes(codes);
  }

  /// Read a 16-bit word from the stream.
  @override
  int readUint16() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    if (byteOrder == ByteOrder.big_endian) {
      return (b1 << 8) | b2;
    }
    return (b2 << 8) | b1;
  }

  /// Read a 32-bit word from the stream.
  @override
  int readUint32() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    if (byteOrder == ByteOrder.big_endian) {
      return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    }
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  /// Read a 64-bit word form the stream.
  @override
  int readUint64() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    final b5 = buffer[offset++] & 0xff;
    final b6 = buffer[offset++] & 0xff;
    final b7 = buffer[offset++] & 0xff;
    final b8 = buffer[offset++] & 0xff;
    if (byteOrder == ByteOrder.big_endian) {
      return (b1 << 56) |
          (b2 << 48) |
          (b3 << 40) |
          (b4 << 32) |
          (b5 << 24) |
          (b6 << 16) |
          (b7 << 8) |
          b8;
    }
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  @override
  Uint8List toUint8List() {
    var len = length;
    if ((offset + len) > buffer.length) {
      len = buffer.length - offset;
    }
    final bytes =
        Uint8List.view(buffer.buffer, buffer.offsetInBytes + offset, len);
    return bytes;
  }

  int _length;
}

class FileInputStream extends InputStream {
  final String path;
  final ByteOrder byteOrder;
  RandomAccessFile _file;
  int _fileSize = 0;
  int _filePosition = 0;
  Uint8List _buffer;
  int _bufferSize = 0;
  int _bufferPosition = 0;
  int _maxBufferSize;
  static const int _kDefaultBufferSize = 4096;

  FileInputStream(this.path,
      {this.byteOrder = ByteOrder.big_endian,
      int bufferSize = _kDefaultBufferSize}) {
    _maxBufferSize = bufferSize;
    _buffer = Uint8List(_maxBufferSize);
    _file = File(path).openSync();
    _fileSize = _file.lengthSync();
    _readBuffer();
  }

  void close() {
    _file.closeSync();
    _fileSize = 0;
  }

  @override
  int get length => _fileSize;

  @override
  int get position => _filePosition - bufferRemaining;

  @override
  bool get isEOS =>
      (_filePosition >= _fileSize) && (_bufferPosition >= _bufferSize);

  int get bufferSize => _bufferSize;

  int get bufferPosition => _bufferPosition;

  int get bufferRemaining => _bufferSize - _bufferPosition;

  int get fileRemaining => _fileSize - _filePosition;

  @override
  void reset() {
    _filePosition = 0;
    _file.setPositionSync(0);
    _readBuffer();
  }

  @override
  void skip(int length) {
    if ((_bufferPosition + length) < _bufferSize) {
      _bufferPosition += length;
    } else {
      var remaining = length - (_bufferSize - _bufferPosition);
      while (!isEOS) {
        _readBuffer();
        if (remaining < _bufferSize) {
          _bufferPosition += remaining;
          break;
        }
        remaining -= _bufferSize;
      }
    }
  }

  @override
  void rewind([int count = 1]) {
    if (_bufferPosition - count < 0) {
      var remaining = (_bufferPosition - count).abs();
      _filePosition = _filePosition - _bufferSize - remaining;
      if (_filePosition < 0) {
        _filePosition = 0;
      }
      _file.setPositionSync(_filePosition);
      _readBuffer();
      return;
    }
    _bufferPosition -= count;
  }

  @override
  int readByte() {
    if (isEOS) {
      return 0;
    }
    if (_bufferPosition >= _bufferSize) {
      _readBuffer();
    }
    if (_bufferPosition >= _bufferSize) {
      return 0;
    }
    return _buffer[_bufferPosition++] & 0xff;
  }

  /// Read a 16-bit word from the stream.
  @override
  int readUint16() {
    var b1 = 0;
    var b2 = 0;
    if ((_bufferPosition + 2) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
    }
    if (byteOrder == ByteOrder.big_endian) {
      return (b1 << 8) | b2;
    }
    return (b2 << 8) | b1;
  }

  /// Read a 32-bit word from the stream.
  @override
  int readUint32() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    if ((_bufferPosition + 4) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
    }

    if (byteOrder == ByteOrder.big_endian) {
      return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    }
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  /// Read a 64-bit word form the stream.
  @override
  int readUint64() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    var b5 = 0;
    var b6 = 0;
    var b7 = 0;
    var b8 = 0;
    if ((_bufferPosition + 8) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
      b5 = _buffer[_bufferPosition++] & 0xff;
      b6 = _buffer[_bufferPosition++] & 0xff;
      b7 = _buffer[_bufferPosition++] & 0xff;
      b8 = _buffer[_bufferPosition++] & 0xff;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
      b5 = readByte();
      b6 = readByte();
      b7 = readByte();
      b8 = readByte();
    }

    if (byteOrder == ByteOrder.big_endian) {
      return (b1 << 56) |
          (b2 << 48) |
          (b3 << 40) |
          (b4 << 32) |
          (b5 << 24) |
          (b6 << 16) |
          (b7 << 8) |
          b8;
    }
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  @override
  Uint8List readBytes(int length) {
    if (isEOS) {
      return Uint8List.fromList(<int>[]);
    }

    if (_bufferPosition == _bufferSize) {
      _readBuffer();
    }

    if (_remainingBufferSize >= length) {
      final bytes = _buffer.sublist(_bufferPosition, _bufferPosition + length);
      _bufferPosition += length;
      return bytes;
    }

    var total_remaining = fileRemaining + _remainingBufferSize;
    if (length > total_remaining) {
      length = total_remaining;
    }

    final bytes = Uint8List(length);

    var offset = 0;
    while (length > 0) {
      var remaining = _bufferSize - _bufferPosition;
      var end = (length > remaining) ? _bufferSize : (_bufferPosition + length);
      final l = _buffer.sublist(_bufferPosition, end);
      // TODO probably better to use bytes.setRange here.
      for (var i = 0; i < l.length; ++i) {
        bytes[offset + i] = l[i];
      }
      offset += l.length;
      length -= l.length;
      _bufferPosition = end;
      if (length > 0 && _bufferPosition == _bufferSize) {
        _readBuffer();
        if (_bufferSize == 0) {
          break;
        }
      }
    }

    return bytes;
  }

  @override
  Uint8List toUint8List() {
    return readBytes(_fileSize);
  }

  /// Read a null-terminated string, or if [len] is provided, that number of
  /// bytes returned as a string.
  @override
  String readString({int size, bool utf8 = true}) {
    final codes = <int>[];
    if (size == null) {
      while (!isEOS) {
        var c = readByte();
        if (!utf8) {
          var c2 = readByte();
          c = (c2 << 8) | c;
        }
        if (c == 0) {
          break;
        }
        codes.add(c);
      }
    } else {
      while (size > 0) {
        var c = readByte();
        size--;
        if (!utf8) {
          var c2 = readByte();
          size--;
          c = (c2 << 8) | c;
        }
        if (c == 0) {
          break;
        }
        codes.add(c);
      }
    }

    return utf8 ? Utf8Decoder().convert(codes) : String.fromCharCodes(codes);
  }

  int get _remainingBufferSize => _bufferSize - _bufferPosition;

  void _readBuffer() {
    _bufferPosition = 0;
    _bufferSize = _file.readIntoSync(_buffer);
    if (_bufferSize == 0) {
      return;
    }
    _filePosition += _bufferSize;
  }
}

