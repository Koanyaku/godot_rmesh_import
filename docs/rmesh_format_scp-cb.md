
# SCP – Containment Breach RMesh file format

This document explains how RMesh files from SCP – Containment Breach are stored internally. The files in question are from **SCP – Containment Breach v1.3.11**.

**Note:** Non-representable characters in hex-to-text examples have been replaced with periods. The parts of hex code which are of main focus are enclosed in >[ ]<.

Before we start, you should understand the term 'B3D string' and how it works, since it's used quite a lot here. A B3D string (or Blitz3D string) is a data type used by Blitz3D, the engine used by SCP – CB.

## B3D string structure:

**Example B3D string:**

```
Hex: 08 00 00 00 52 6F 6F 6D 4D 65 73 68
Text: ....RoomMesh

>[08 00 00 00]< 52 6F 6F 6D 4D 65 73 68

4-byte 'int' value representing the string's length in bytes. In this case, 8.

08 00 00 00 >[52 6F 6F 6D 4D 65 73 68]<

Variable-byte 'string' value, which is the string itself. In this case, 'RoomMesh'.
```

Now, we can finally look onto how the RMesh files are stored.

## File structure

At the file's start, a B3D string header is written. This is always either 'RoomMesh' or 'RoomMesh.HasTriggerBox' if the map contains triggers boxes.

```
Hex: >[08 00 00 00 52 6F 6F 6D 4D 65 73 68]< 0D 00 00 00
Text: ....RoomMesh....

Without trigger boxes.
```

```
Hex: >[16 00 00 00 52 6F 6F 6D 4D 65 73 68 2E 48 61 73 54 72 69 67 67 65 72 42 6F 78]< 28 00
Text: ....RoomMesh.HasTriggerBox(.

With trigger boxes.
```

After the header, the map's texture count is stored. This is the number of unique textures the map contains.

```
Hex: 4D 65 73 68 >[0D 00 00 00]< 02 10 00 00
Text: Mesh........

4-byte 'int' value representing the unique texture count. In this case, 13.
```

Next, for each unique texture, the data for all faces with that texture is stored. SCP – CB handles opaque and transparent textures differently. First, we need to understand what different 'texture flags' represent. These are taken from SCP – CB's code comments.

```
Texture flags:

1 – The texture is opaque (non-transparent).
2 – The texture is a lightmap texture.
3 – The texture has transparency.
```

---

### **How opaque textures are handled:**

For every opaque texture, a lightmap is generated.
First, a 1-byte 'Byte' value gets stored, which is the lightmap's texture flag.

```
Hex: 0D 00 00 00 >[02]< 10 00 00 00 72 6F 6F 6D 34
Text: .........room4

In this case, the flag is 2, meaning the texture is a lightmap.
```

Then, the lightmap texture's path relative to the .rmesh file's directory is stored as a B3D string.

```
Hex: 02 >[10 00 00 00 72 6F 6F 6D 34 70 69 74 5F 6C 6D 31 2E 70 6E 67]< 01 11
Text: .....room4pit_lm1.png..
```

After that, the same is done for the actual texture. A 1-byte 'Byte' value is stored, which is the actual texture's texture flag.

```
Hex: 6C 6D 31 2E 70 6E 67 >[01]< 11 00 00 00 63 6F 6E 63 72
Text: lm1.png.....concr
```

Then, the texture path is stored as a B3D string.

```
Hex: 01 >[11 00 00 00 63 6F 6E 63 72 65 74 65 66 6C 6F 6F 72 2E 6A 70 67]< F0 00
Text: .....concretefloor.jpgð.
```

Next, the amount of vertices that are associated with the texture is stored.

```
Hex: 6F 72 2E 6A 70 67 >[F0 00 00 00]< 00 00 80 44
Text: or.jpgð.....€D

4-byte 'int' value representing the vertex count. In this case, 240.
```

For each vertice, some data gets stored. This data _always_ takes up 31 bytes.

```
4-byte 'float32' value, representing the vertex' X position (in SCP – CB).
4-byte 'float32' value, representing the vertex' Y position (in SCP – CB).
4-byte 'float32' value, representing the vertex' Z position (in SCP – CB).

4-byte 'float32' value, representing the U value of the texture's UV values.
4-byte 'float32' value, representing the V value of the texture's UV values.

4-byte 'float32' value, representing the U value of the lightmap texture's UV values.
4-byte 'float32' value, representing the V value of the lightmap texture's UV values.

Three 1-byte values. These are the vertex' vertex colors.
```

### **How transparent textures are handled:**

For transparent textures, a lightmap is _not_ generated.
First, a 1-byte 'Byte' value gets stored, which is the lightmap's texture flag. This flag is _always_ 1.

```
Hex: 62 01 00 00 >[01]< 00 00 00 00 03 09 00 00 00 67 6C 61
Text: b.............gla
```

If the lightmap isn't generated, an empty B3D string is written taking up 4 bytes.

```
Hex: 62 01 00 00 01 >[00 00 00 00]< 03 09 00 00 00 67 6C 61
Text: b.............gla
```

After that, for the actual texture. A 1-byte 'Byte' value is stored, which is the actual texture's texture flag. This flag is _always_ 3.

```
Hex: 00 00 00 00 >[03]< 09 00 00 00 67 6C 61 73 73 2E 70 6E 67 60 00
Text: .........glass.png`.
```

Then, the texture's path relative to the .rmesh file's directory is stored as a B3D string.

```
Hex: 00 00 00 00 03 >[09 00 00 00 67 6C 61 73 73 2E 70 6E 67]< 60 00
Text: .........glass.png`.
```

Next, the amount of all the vertices that are associated with the texture are stored.

```
Hex: 67 6C 61 73 73 2E 70 6E 67 >[60 00 00 00]< FE 7F 29 45
Text: glass.png`...þ.)E

4-byte 'int' value representing the vertex count. In this case, 96.
```

For each vertice, some data gets stored. This data _always_ takes up 31 bytes.

```
4-byte 'float32' value, representing the vertex' X position (in SCP – CB).
4-byte 'float32' value, representing the vertex' Y position (in SCP – CB).
4-byte 'float32' value, representing the vertex' Z position (in SCP – CB).

4-byte 'float32' value, representing the U value of the texture's UV values.
4-byte 'float32' value, representing the V value of the texture's UV values.

4-byte 'float32' value, representing the U value of the lightmap texture's UV values.
4-byte 'float32' value, representing the V value of the lightmap texture's UV values.

Three 1-byte values. These are the vertex' vertex colors.
```

---

After the data for each vertex is stored, the amount of all the triangles that are associated with the texture is stored.

```
Hex: 3D FF FF FF >[18 00 00 00]< 00 00 00 00 01
Text: =ÿÿÿ.........

3D FF FF FF >[18 00 00 00]< 00 00 00 00 01

4-byte 'int' value representing the triangle count. In this case, 24.
```

After the vertex data, the triangle indices are stored.  Each indice is a 4-byte 'int' value. The amount of indices is the triangle count * 3. So, in this example, there would be 30 indices written, so that means the indice data would take up 288 bytes (24 * 3 * 4).

```
Hex: 18 00 00 00 00 00 00 00 01 00 00 00 02 00 00 00 03 00 00 00 00
Text: ....................

18 00 00 00 00 00 00 00 >[01 00 00 00]< 02 00 00 00 03 00 00 00 00

One of the indices stored. In this case, 1, and after it, 2, 3 and so on.
```

Next, the number of invisible collisions (invisible surfaces with collision) is stored.

```
Hex: 2E 00 00 00 01 00 00 00 12 00 00 00 00 80 83 44
Text: .............€ƒD

>[2E 00 00 00]< 01 00 00 00 12 00 00 00 00 80 83 44

Leftover indice data from textures.

2E 00 00 00 >[01 00 00 00]< 12 00 00 00 00 80 83 44

Number of invisible collision surfaces. In this case, 1.
```

For each invisible collision surface, the total vertex count is stored.

```
Hex: 2E 00 00 00 01 00 00 00 12 00 00 00 00 80 83 44
Text: .............€ƒD

2E 00 00 00 01 00 00 00 >[12 00 00 00]< 00 80 83 44

This invisible collision surface's vertex count. In this case, 18.
```

For each vertice, some data gets stored. This data _always_ takes up 12 bytes.

```
4-byte 'float32' type, representing the vertex' X position (in SCP – CB).
4-byte 'float32' type, representing the vertex' Y position (in SCP – CB).
4-byte 'float32' type, representing the vertex' Z position (in SCP – CB).
```

Then, the triangle count is stored.

```
Hex: 00 00 68 44 08 00 00 00 00 00 00 00 01 00 00 00
Text: ..hD............

>[00 00 68 44]< 08 00 00 00 00 00 00 00 01 00 00 00

Excerpt from the end of the invisible collision vertex data.

00 00 68 44 >[08 00 00 00]< 00 00 00 00 01 00 00 00

4-byte 'int' value representing the triangle count. In this case, 8.
```

After that, the triangle indices are stored as 4-byte 'int' values.

```
Hex: 08 00 00 00 00 00 00 00 01 00 00 00 02 00 00 00 03 00 00 00 04 00 00 00
Text: ........................

08 00 00 00 >[00 00 00 00 01 00 00 00 02 00 00 00 03 00 00 00 04 00 00 00]<

Some of the beginning indices. In this case, 0, 1, 2, 3, 4 and so on.
```

---

Next, if the map contains trigger boxes (header is RoomMesh.HasTriggerBox), the data for them is stored.

First, the amount of trigger boxes is stored.

```
Hex: 0E 00 00 00 10 00 00 00 03 00 00 00 01 00 00 00
Text: ................

>[0E 00 00 00 10 00 00 00]< 03 00 00 00 01 00 00 00

Leftover indice data from invisible collisions.

0E 00 00 00 10 00 00 00 >[03 00 00 00]< 01 00 00 00

4-byte 'int' value representing the amount of trigger boxes. In this case, 3.
```

Then, for each trigger box, some data gets stored.

First, the surface amount for the trigger box is stored.

```
Hex: 03 00 00 00 01 00 00 00 18 00 00 00 00 00 2A 45 00
Text: ..............*E.

03 00 00 00 >[01 00 00 00]< 18 00 00 00 00 00 2A 45 00

4-byte 'int' value representing the surface count for the trigger box. In this case, 1.
```

For each surface, some data is stored.

First, the surface's vertex count is stored.

```
Hex: 03 00 00 00 01 00 00 00 18 00 00 00 00 00 2A 45 00
Text: ..............*E.

03 00 00 00 01 00 00 00 >[18 00 00 00]< 00 00 2A 45 00

4-byte 'int' value representing the vertex count for the surface. In this case, 24.
```

Then, for each vertex, some data is stored.

```
4-byte 'float32' value representing the vertex' X position (in SCP – CB).
4-byte 'float32' value representing the vertex' Y position (in SCP – CB).
4-byte 'float32' value representing the vertex' Z position (in SCP – CB).
```

Next, the surface triangle count is stored.

```
Hex: 00 00 BC 43 00 00 E0 C3 0C 00 00 00 00 00 00 00 01 00 00 00
Text: ..¼C..àÃ............

?[00 00 BC 43 00 00 E0 C3]< 0C 00 00 00 00 00 00 00 01 00 00 00

Leftover trigger box vertex data.

00 00 BC 43 00 00 E0 C3 >[0C 00 00 00]< 00 00 00 00 01 00 00 00

4-byte 'int' value representing the surface triangle count. In this case, 12.
```

Last, the trigger box' name is stored as a B3D string.

```
Hex: 14 00 00 00 16 00 00 00 0E 00 00 00 31 37 33 73 63 65 6E 65 5F 74 69 6D 65 72 01 00 00 00
Text: ............173scene_timer....

>[14 00 00 00 16 00 00 00]< 0E 00 00 00 31 37 33 73 63 65 6E 65 5F 74 69 6D 65 72 01 00 00 00

Some leftover trigger box triangle indice data.

14 00 00 00 16 00 00 00 >[0E 00 00 00 31 37 33 73 63 65 6E 65 5F 74 69 6D 65 72]< 01 00 00 00

The name of the trigger box as a B3D string.
```

---

After all that comes the entity data. First, the collective amount of all entites present in the map is stored.

```
Hex: 63 65 6E 65 5F 65 6E 64 41 00 00 00 05 00 00 00
Text: cene_endA.......

>[63 65 6E 65 5F 65 6E 64]< 41 00 00 00 05 00 00 00

Leftover trigger box data.

63 65 6E 65 5F 65 6E 64 >[41 00 00 00]< 05 00 00 00

4-byte 'int' value representing the entity count. In this case, 65.
```

Then, for each entity type, some data for it is stored.

### Screen entity (classname screen)

```
B3D string "screen".

4-byte 'float32' value representing the screen's X position (in SCP – CB).
4-byte 'float32' value representing the screen's Y position (in SCP – CB).
4-byte 'float32' value representing the screen's Z position (in SCP – CB).

B3D string representing the file path of the image the screen uses.
```

**Example screen entity:**

```
Hex: 06 00 00 00 73 63 72 65 65 6E 00 00 00 00 00 00 60 43 00 00 60 C3 0A 00 00 00 73 63 72 65 65 6E 2F 30 30 38

Text: ....screen......`C..`Ã....screen/008

X: 0, Y: 224, Z: -224, Image path: screen/008
```

### Waypoint entity (classname waypoint)

```
B3D string "waypoint".

4-byte 'float32' value representing the waypoint's X position (in SCP – CB).
4-byte 'float32' value representing the waypoint's Y position (in SCP – CB).
4-byte 'float32' value representing the waypoint's Z position (in SCP – CB).
```

**Example waypoint entity:**

```
Hex: 08 00 00 00 77 61 79 70 6F 69 6E 74 00 00 90 43 00 00 20 43 00 00 28 44

Text: ....waypoint...C.. C..(D

X: 288 Y: 160 Z: 672
```

### Light entity (classname light)

```
B3D string "light".

4-byte 'float32' value representing the light's X position (in SCP – CB).
4-byte 'float32' value representing the light's Y position (in SCP – CB).
4-byte 'float32' value representing the light's Z position (in SCP – CB).

4-byte 'float32' value representing the light's range.
B3D string representing the light color.
4-byte 'float32' value representing the light's intensity.
```

**Example light entity:**

```
Hex: 05 00 00 00 6C 69 67 68 74 00 00 40 44 00 00 40 43 00 00 A4 44 00 00 16 44 0B 00 00 00 31 32 38 20 32 35 35 20 32 35 35 00 00 00 40

Text: ....light..@D..@C..¤D...D....128 255 255...@

X: 768, Y: 192, Z: 1312, Range: 600, Color: 128 255 255, Intensity: 2
```

### Spotlight entity (classname spotlight)

```
B3D string "spotlight".

4-byte 'float32' value representing the light's X position (in SCP – CB).
4-byte 'float32' value representing the light's Y position (in SCP – CB).
4-byte 'float32' value representing the light's Z position (in SCP – CB).

4-byte 'float32' value representing the light's range.
B3D string representing the light color.
4-byte 'float32' value representing the light's intensity.
B3D string representing the spotlight's angles.

4-byte 'int' value representing the spotlight's inner cone angle.
4-byte 'int' value representing the spotlight's outer cone angle.
```

**Example spotlight entity:**

```
Hex: 09 00 00 00 73 70 6F 74 6C 69 67 68 74 00 00 C2 C3 00 00 BC 43 00 00 20 C2 00 00 48 44 0B 00 00 00 32 35 35 20 32 35 35 20 32 35 35 9A 99 99 3F 06 00 00 00 39 30 20 30 20 30 23 00 00 00 2D 00 00 00

Text: ....spotlight..ÂÃ..¼C.. Â..HD....255 255 255š™™?....90 0 0#...-...

X: -388, Y: 376, Z: -40, Range: 800, Color: 255 255 255, Intensity: 1.20000004768372, Angles: 90 0 0, Inner cone angle: 35, Outer cone angle: 45
```

### Sound emitter entity (classname soundemitter)

```
B3D string "soundemitter".

4-byte 'float32' value representing the sound emitter's X position (in SCP – CB).
4-byte 'float32' value representing the sound emitter's Y position (in SCP – CB).
4-byte 'float32' value representing the sound emitter's Z position (in SCP – CB).

4-byte 'int' value representing the sound emitter's sound index.
4-byte 'float32' value representing the sound emitter's range.
```

**Note:** SCP – CB uses 'sound indexes' to play back sounds from sound emitters.

**Example sound emitter entity:**

```
Hex: 0C 00 00 00 73 6F 75 6E 64 65 6D 69 74 74 65 72 00 00 60 44 00 00 00 43 FD FF 1F 43 01 00 00 00 00 00 FA 43

Text: ....soundemitter..`D...Cýÿ.C......úC

X: 896, Y: 128, Z: 159.999954223633, Sound index: 1, Range: 500
```

### Player start entity (classname playerstart)

```
B3D string "playerstart"

4-byte 'float32' value representing the player start's X position (in SCP – CB).
4-byte 'float32' value representing the player start's Y position (in SCP – CB).
4-byte 'float32' value representing the player start's Z position (in SCP – CB).

B3D string representing the player start's angles.
```

**Example player start entity:**

**Note:** (I think) no player start entity is used in any of SCP – CB's .rmesh files, as I couldn't find any.

```
Hex: 0B 00 00 00 70 6C 61 79 65 72 73 74 61 72 74 00 00 E0 42 00 00 AA 43 00 40 B5 44 06 00 00 00 30 20 34 35 20 30

Text: ....playerstart..àB..ªC.@µD....0 45 0

X: 112, Y: 340, Z: 1450, Angles: 0 45 0
```

### Model entity (classname model)

```
B3D string "model".
B3D string representing the model name stripped of the file path.

4-byte 'float32' value representing the model's X position (in SCP – CB).
4-byte 'float32' value representing the model's Y position (in SCP – CB).
4-byte 'float32' value representing the model's Z position (in SCP – CB).

4-byte 'float32' value representing the model's Pitch (X) rotation (in SCP – CB).
4-byte 'float32' value representing the model's Yaw (Y) rotation (in SCP – CB).
4-byte 'float32' value representing the model's Roll (Z) rotation (in SCP – CB).

4-byte 'float32' value representing the model's X scale (in SCP – CB).
4-byte 'float32' value representing the model's Y scale (in SCP – CB).
4-byte 'float32' value representing the model's Z scale (in SCP – CB).
```

**Example model entity:**

```
Hex: 05 00 00 00 6D 6F 64 65 6C 0F 00 00 00 63 6F 6E 74 64 6F 6F 72 66 72 61 6D 65 2E 78 00 00 6C 44 00 00 A0 C4 06 00 00 38 00 00 00 80 FD FF B3 C2 00 00 00 00 FF FF 0B 42 00 00 50 42 FF FF 47 42

Text: ....model....contdoorframe.x..1D.. Ä...8...€ýÿ³Â....ÿÿ.B..PBÿÿGB

Model name: contdoorframe.x, Position X: 944, Position Y: -1280, Position Z: 3.05175999528728E-5, Rotation Pitch (X): -0, Rotation Yaw (Y): -89.9999771118164, Rotation Roll (Z): 0, Scale X: 34.9999961853027, Scale Y: 52, Scale Z: 49.9999961853027
```
