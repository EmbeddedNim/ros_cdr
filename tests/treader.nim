# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import strutils
import stew/byteutils

import ros_cdr/cdrtypes
import ros_cdr/reader
import ros_cdr/writer

# Example tf2_msgs/TFMessage
const tf2_msg_TFMessage: string =
     "0001000001000000cce0d158f08cf9060a000000626173655f6c696e6b000000060000007261646172000000ae47e17a14ae0e4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f03f"

proc near*[T: SomeFloat](x, y: T, eps: T): bool =
  result = abs(x-y) < eps
proc `~=` *[T: float64](x, y: T): bool =
  near(x, y, 1.0e-6)
proc `~=` *[T: float32](x, y: T): bool =
  near(x, y, 1.0e-4)

suite "CdrReader":
  test "parses an example tf2_msgs/TFMessage message":
    
    let data = $cast[string](tf2_msg_TFMessage.hexToSeqByte())
    check tf2_msg_TFMessage == data.toHex().toLowerAscii()

    # echo "tf2_msg_TFMessage: ", toHex(data)
    let reader = newCdrReader(data)
    check(reader.decodedBytes == 4)
    check(reader.kind == EncapsulationKind.CDR_LE)

    # 00,01,00,00_01,00,00,00_cc,e0,d1,58_f08cf9060a000000626173655f6c696e6b000000060000007261646172000000ae47e17a14ae0e4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f03f
    # geometry_msgs/TransformStamped[] transforms
    check(reader.sequenceLength() == 1)
    # std_msgs/Header header
    # time stamp
    check(reader.read(uint32) == 1490149580) # uint32 sec # 0x58D1E0CC
    check(reader.read(uint32) == 117017840) # uint32 nsec
    let xx = reader.readStr()
    check(xx == "base_link") # string frame_id
    echo ""
    let yy = reader.readStr()
    echo "yy:len: ", yy.len(), " ", "radar".len()
    echo "yy: `", yy, "`"
    check(yy == "radar") # string child_frame_id
    # geometry_msgs/Transform transform
    # geometry_msgs/Vector3 translation
    check(reader.read(float64) ~= 3.835) # float64 x
    check(reader.read(float64) ~= 0) # float64 y
    check(reader.read(float64) ~= 0) # float64 z
    # geometry_msgs/Quaternion rotation
    check(reader.read(float64) ~= 0) # float64 x
    check(reader.read(float64) ~= 0) # float64 y
    check(reader.read(float64) ~= 0) # float64 z
    check(reader.read(float64) ~= 1) # float64 w

    check(reader.getPosition() == data.len())
    check(reader.decodedBytes() == data.len)
    check(reader.byteLength() == data.len)

  test "parses an example rcl_interfaces/ParameterEvent":
    
    let datastr = "00010000a9b71561a570ea01110000002f5f726f7332636c695f33373833363300000000010000000d0000007573655f73696d5f74696d650001000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000"
    let data = $cast[string](datastr.hexToSeqByte())
    check datastr == data.toHex().toLowerAscii()

    # echo "tf2_msg_TFMessage: ", toHex(data)
    let reader = newCdrReader(data)
    check(reader.decodedBytes == 4)
    check(reader.kind == EncapsulationKind.CDR_LE)

    # builtin_interfaces/Time stamp
    check(reader.read(uint32) == 1628813225) # uint32 sec
    check(reader.read(uint32) == 32141477) # uint32 nsec
    # string node
    check(reader.readStr() == "/_ros2cli_378363")

    # Parameter[] new_parameters
    check(reader.sequenceLength() == 1)
    check(reader.readStr() == "use_sim_time") # string name
    # ParameterValue value
    check(reader.read(uint8) == 1) # uint8 type
    check(reader.read(int8) == 0) # bool bool_value
    check(reader.read(int64) == 0) # int64 integer_value
    check(reader.read(float64) == 0) # float64 double_value
    check(reader.readStr() == "") # string string_value

    check(reader.readSeq(int8) == newSeq[int8]()) # byte[] byte_array_value
    check(reader.readSeq(uint8) == newSeq[uint8]()) # bool[] bool_array_value
    check(reader.readSeq(int64) == newSeq[int64]()) # int64[] integer_array_value
    check(reader.readSeq(float64) == newSeq[float64]()) # float64[] double_array_value
    check(reader.readStrSeq() == newSeq[string]()) # string[] string_array_value

    # Parameter[] changed_parameters
    check(reader.sequenceLength() == 0)

    # Parameter[] deleted_parameters
    check(reader.sequenceLength() == 0)

    check(reader.getPosition() == data.len)

  test "reads big endian values":
    let datastr = "000100001234000056789abcdef0000000000000"
    let data = $cast[string](datastr.hexToSeqByte())
    check datastr == data.toHex().toLowerAscii()

    # echo "tf2_msg_TFMessage: ", toHex(data)
    let reader = newCdrReader(data)

    check(reader.readBe(uint16) == 0x1234'u16)
    check(reader.readBe(uint32) == 0x56789abc'u32)
    check(reader.readBe(uint64) == 0xdef0000000000000'u64)

  test "seeks to absolute and relative positions":
    let data = $cast[string](tf2_msg_TFMessage.hexToSeqByte())
    var reader = newCdrReader(data);

    reader.seekTo(4 + 4 + 4 + 4 + 4 + 10 + 4 + 6);
    check(reader.read(float64) ~= 3.835)

    # // This works due to aligned reads
    reader.seekTo(4 + 4 + 4 + 4 + 4 + 10 + 4 + 3);
    check(reader.read(float64) ~= 3.835)

    reader.seek(-8);
    check(reader.read(float64) ~= 3.835)
    check(reader.read(float64) ~= 0)

  template testInts(expected: untyped) =
    let writer = newCdrWriter()
    writer.writeArray(expected)

    let reader = newCdrReader(writer.data)
    echo "data: array: ", reader.ss.data.tohex()
    let vals = reader.readSeq(typeof(expected[0]), reader.sequenceLength())
    check vals == expected

  test "read ints ":
    testInts([-128.int8, 127, 3])
  test "read u8 ":
    testInts([0.uint8, 255, 3])
  test "read i16 ":
    testInts([-32768.int16, 32767, -3])
  test "read u16 ":
    testInts([0.uint16, 65535, 3])
  test "read i32 ":
    testInts([-2147483648.int32, 2147483647, 3])
  test "read u32 ":
    testInts( [0.uint32, 4294967295.uint32, 3])

  template testReads(expected: untyped) =
    let writer = newCdrWriter()
    writer.writeArray(expected)

    let reader = newCdrReader(writer.data)
    let res = reader.readSeq(typeof(expected[0]))
    check res == expected

  test "reads farray float32Array":
    testReads [-3.835'f32, 0, 3.1415]
  test "reads farray float32Array":
    testReads [-3.835'f32, 0, 3.1415]
  test "reads farray float32Array":
    testReads [1'f32, 2, 3, 4, 5, 6, 7, 8, 9, 10, -0.123456789121212121212]

  test "reads multiple arrays":
    let writer = newCdrWriter()
    writer.writeArray([5.5'f32, 6.5])
    writer.writeArray([7.5'f32, 8.5])

    let reader = newCdrReader(writer.data)
    let res1 = reader.readSeq(float32)
    let exp1 = @[5.5'f32, 6.5]
    for i in 0..<res1.len():
      check res1[i] == exp1[i]
    let res2 = reader.readSeq(float32)
    let exp2 = @[7.5'f32, 8.5]
    for i in 0..<res2.len():
      check res2[i] == exp2[i]
    check(reader.getPosition == writer.getPosition())

  test "reads stringArray":
    let writer = newCdrWriter()
    writer.sequenceLength(3);
    writer.write("abc");
    writer.write("");
    writer.write("test string");

    let reader = newCdrReader(writer.data)

    check(reader.readStrSeq(reader.sequenceLength()) == @["abc", "", "test string"])
    check(reader.getPosition == writer.data.len)