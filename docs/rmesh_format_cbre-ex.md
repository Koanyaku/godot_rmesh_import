
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
Hex: 6F 72 2E 6A 70 67 F0 00 00 00 00 00 80 44
Text: or.jpgð.....€D

4-byte 'int' value representing the vertex count. In this case, 240.
```

For each vertice, some data gets stored. This data _always_ takes up 31 bytes.

```
4-byte 'float' value, representing the vertex' X position (in SCP – CB).
4-byte 'float' value, representing the vertex' Y position (in SCP – CB).
4-byte 'float' value, representing the vertex' Z position (in SCP – CB).

4-byte 'float' value, representing the U value of the texture's UV values.
4-byte 'float' value, representing the V value of the texture's UV values.

4-byte 'float' value, representing the U value of the lightmap texture's UV values.
4-byte 'float' value, representing the V value of the lightmap texture's UV values.

Three 1-byte values. These are the vertex' vertex colors.
```

### **How transparent textures are handled:**

For transparent textures, a lightmap is _not_ generated.
First, a 1-byte 'Byte' value gets stored, which is the lightmap's texture flag. This flag is _always_ 1.

```
Hex: 06 00 00 00 07 00 00 00 >[00]< 03 0D 00 00 00 6D 61 70 2F
Text: ..............map/
```

After that, for the actual texture. A 1-byte 'Byte' value is stored, which is the actual texture's texture flag. This flag is _always_ 3.

```
Hex: 06 00 00 00 07 00 00 00 00 >[03]< 0D 00 00 00 6D 61 70 2F
Text: ..............map/
```

Then, the texture's path relative to the .rmesh file's directory is stored as a B3D string.

```
Hex: 00 03 0D 00 00 00 6D 61 70 2F 67 6C 61 73 73 2E 70 6E 67 3C 00
Text: ......map/glass.png<.
```

Next, CBRE-EX adds up all the vertices that are associated with the texture and stores the amount.

```
Hex: 6F 72 2E 6A 70 67 >[14 00 00 00]< 00 00 C0 C2
Text: or.jpg......ÀÂ

4-byte 'Int32' value representing the vertex count. In this case, 20.
```

For each vertice, some data gets stored. This data _always_ takes up 31 bytes.

```
4-byte 'float' value, representing the vertex' X position (in SCP – CB).
4-byte 'float' value, representing the vertex' Y position (in SCP – CB).
4-byte 'float' value, representing the vertex' Z position (in SCP – CB).

4-byte 'float' value, representing the U value of the texture's UV values.
4-byte 'float' value, representing the V value of the texture's UV values.

4-byte 'float' value, representing the U value of the lightmap texture's UV values. This value is always 0.0.
4-byte 'float' value, representing the V value of the lightmap texture's UV values. This value is always 0.0.

Three filler bytes. These are supposed to be the vertex' vertex colors, but they are always stored as 255 (FF).
```

---

After the data for each vertex is stored, CBRE-EX adds up all the triangles that are associated with the texture and stores the amount.

```
Hex: 00 00 73 3E FF FF FF 0A 00 00 00 00 00 00 00 01
Text: ..s>ÿÿÿ.........

>[00 00 73 3E FF FF FF]< 0A 00 00 00 00 00 00 00 01

Excerpt from the vertex data. Notice the three FF filler bytes at the end.

00 00 73 3E FF FF FF >[0A 00 00 00]< 00 00 00 00 01

4-byte 'Int32' value representing the triangle count. In this case, 10.
```

After the vertex data, the triangle indices are stored.  Each indice is a 4-byte 'Int32' value. The amount of indices is the triangle count * 3. So, in this example, there would be 30 indices written, so that means the indice data would take up 120 bytes (10 * 3 * 4).

```
Hex: 00 00 00 00 01 00 00 00 02 00 00 00 00 00 00 00 02 00 00 00 03 00 00 00 04 00 00 00
Text: ............................

00 00 00 00 >[01 00 00 00]< 02 00 00 00 00 00 00 00 02 00 00 00 03 00 00 00 04 00 00 00

One of the indices stored. In this case, 1, and after it, 2, 0, 2, 3, 4 and so on.
```

Next, a 4-byte 'Int32' value is stored, that is either be 0 or 1, depending on if the map has 'invisible collisions'. It is 0 if the map doesn't include them, and 1 if it does. These are faces with the 'tooltextures/invisible_collision' texture in CBRE-EX.

---

### When invisible collisions are included:

```
Hex: 1E 00 00 00 1F 00 00 00 01 00 00 00 08 00 00 00
Text: ................

>[1E 00 00 00 1F 00 00 00]< 01 00 00 00 08 00 00 00

Some of the last indices stored for normal textures.

1E 00 00 00 1F 00 00 00 >[01 00 00 00]< 08 00 00 00

When invisible collisions are included, value is 1.
```

Next, CBRE-EX adds up all the vertices that are associated with the invisible collisions and stores the amount.

```
Hex: 1F 00 00 00 01 00 00 00 >[08 00 00 00]< F7 FF 7F 44
Text: ............÷ÿ.D

Invisible collision vertex count. In this case, 8.
```

For each invisible collision vertice, some data gets stored. This data _always_ takes up 12 bytes.

```
4-byte 'Decimal' type, representing the vertex' X position (in CBRE-EX).
4-byte 'Decimal' type, representing the vertex' Z position (in CBRE-EX).
4-byte 'Decimal' type, representing the vertex' Y position (in CBRE-EX).
```

Then, the invisible collision triangle count is stored.

```
Hex: 00 00 80 44 04 00 00 00 00 00 00 00
Text: ..€D........

>[00 00 80 44]< 04 00 00 00 00 00 00 00

Excerpt from the end of the invisible collision vertex data.

00 00 80 44 >[04 00 00 00]< 00 00 00 00

4-byte 'Int32' value representing the triangle count. In this case, 4.
```



### When invisible collisions are not included:

```
Hex: 3A 00 00 00 3B 00 00 00 00 00 00 00 01 00 00 00
Text: :...;...........

>[3A 00 00 00 3B 00 00 00]< 00 00 00 00 01 00 00 00

Some of the last indices stored for normal textures.

3A 00 00 00 3B 00 00 00 >[00 00 00 00]< 01 00 00 00

When invisible collisions are not included, value is 0.
```

---

After all that comes the entity data. First, CBRE-EX stores the collective amount of all entites present in the map.

```
Hex: 07 00 00 00 0C 00 00 00 05 00 00 00 6C 69 67 68 74
Text: ............light

>[07 00 00 00]< 0C 00 00 00 05 00 00 00 6C 69 67 68 74

Some leftover indice data.

07 00 00 00 >[0C 00 00 00]< 05 00 00 00 6C 69 67 68 74

4-byte 'Int32' value representing the entity count. In this case, 12.
```

Then, for each entity type, CBRE-EX stores some data for it before storing data for the next entity right after.

### Light entity (classname light)

```
B3D string "light".

4-byte 'Single' value representing the light's X position (in CBRE-EX).
4-byte 'Single' value representing the light's Z position (in CBRE-EX).
4-byte 'Single' value representing the light's Y position (in CBRE-EX).

4-byte 'Single' value representing the light's range.
B3D string representing the light color.
4-byte 'Single' value representing the light's intensity.
```

**Note:** CBRE-EX doesn't actually write a B3D string for the light's color. Instead, it writes the string's length and then the string itself manually (not utilizing the **WriteB3DString** function). However, this is identical to how B3D strings are stored, so that's how it's described here.

**Example light entity:**

```
Hex: 05 00 00 00 6C 69 67 68 74 00 00 40 44 00 00 40 43 00 00 A4 44 00 00 16 44 0B 00 00 00 31 32 38 20 32 35 35 20 32 35 35 00 00 00 40

Text: ....light..@D..@C..¤D...D....128 255 255...@

X: 768, Z: 192, Y: 1312, Range: 600, Color: 128 255 255, Intensity: 2
```

### Waypoint entity (classname waypoint)

```
B3D string "waypoint".

4-byte 'Single' value representing the waypoint's X position (in CBRE-EX).
4-byte 'Single' value representing the waypoint's Z position (in CBRE-EX).
4-byte 'Single' value representing the waypoint's Y position (in CBRE-EX).
```

**Example waypoint entity:**

```
Hex: 08 00 00 00 77 61 79 70 6F 69 6E 74 00 00 90 43 00 00 20 43 00 00 28 44

Text: ....waypoint...C.. C..(D

X: 288 Z: 160 Y: 672
```

### Sound emitter entity (classname soundemitter)

```
B3D string "soundemitter".

4-byte 'Single' value representing the sound emitter's X position (in CBRE-EX).
4-byte 'Single' value representing the sound emitter's Z position (in CBRE-EX).
4-byte 'Single' value representing the sound emitter's Y position (in CBRE-EX).

4-byte 'Int32' value representing the sound emitter's sound index.
4-byte 'Single' value representing the sound emitter's range.
```

**Note:** CBRE-EX (and SCP – CB) use 'sound indexes' to play back sounds from sound emitters.

**Example sound emitter entity:**

```
Hex: 0C 00 00 00 73 6F 75 6E 64 65 6D 69 74 74 65 72 00 00 60 44 00 00 00 43 FD FF 1F 43 01 00 00 00 00 00 FA 43

Text: ....soundemitter..`D...Cýÿ.C......úC

X: 896, Z: 128, Y: 159.999954223633, Sound index: 1, Range: 500
```

### Model entity (classname model)

```
B3D string "model".
B3D string representing the model name stripped of the file path.

4-byte 'Single' value representing the model's X position (in CBRE-EX).
4-byte 'Single' value representing the model's Z position (in CBRE-EX).
4-byte 'Single' value representing the model's Y position (in CBRE-EX).

4-byte 'Single' value representing the model's X rotation (in CBRE-EX).
4-byte 'Single' value representing the model's Y rotation (in CBRE-EX).
4-byte 'Single' value representing the model's Z rotation (in CBRE-EX).

4-byte 'Single' value representing the model's X scale (in CBRE-EX).
4-byte 'Single' value representing the model's Y scale (in CBRE-EX).
4-byte 'Single' value representing the model's Z scale (in CBRE-EX).
```

**Example model entity:**

```
Hex: 05 00 00 00 6D 6F 64 65 6C 0A 00 00 00 31 37 33 62 6F 78 2E 62 33 64 00 00 28 44 00 00 00 42 00 00 C8 44 00 00 B4 43 00 00 00 00 00 00 B4 43 00 00 80 3F 00 00 80 3F 00 00 80 3F

Text: ....model....173box.b3d..(D...B..ÈD..´C......´C..€?..€?..€?

Model name: 173box.b3d, Position X: 672, Position Z: 32, Position Y: 1600, Rotation X: 360, Rotation Y: 0, Rotation Z: 360, Scale X: 1, Scale Y: 1, Scale Z: 1
```

### Screen entity (classname screen)

```
B3D string "screen".

4-byte 'Single' value representing the screen's X position (in CBRE-EX).
4-byte 'Single' value representing the screen's Z position (in CBRE-EX).
4-byte 'Single' value representing the screen's Y position (in CBRE-EX).

B3D string representing the file path of the image the screen uses.
```

**Example screen entity:**

```
Hex: 06 00 00 00 73 63 72 65 65 6E 00 00 00 00 00 00 60 43 00 00 60 C3 0A 00 00 00 73 63 72 65 65 6E 2F 30 30 38

Text: ....screen......`C..`Ã....screen/008

X: 0, Z: 224, Y: -224, Image path: screen/008
```

### Custom entity (classname _classname of custom entity_)

```
B3D string representing the classname of the custom entity.

List of the custom entity's properties.
```

While every custom entity will obviously store different data, CBRE-EX will only fundamentally allow you to store these types:

```
1-byte 'Boolean' value.
4-byte 'Int32' value.
B3D string 'Color255' value.
4-byte 'Single' value.
B3D string 'String' value.
12-byte 'Vector' value containing an X, Z and Y position, each having a length of 4 bytes.
```

The order in which these values are stored is dependent on the entity.