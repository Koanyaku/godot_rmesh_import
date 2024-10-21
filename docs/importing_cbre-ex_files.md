
## Importing CBRE-EX .rmesh files.

### Contents:

1. [Preface](#1-preface)
2. [Importing as Mesh](#2-importing-as-mesh)
3. [Importing as PackedScene](#3-importing-as-packedscene)

## 1. Preface

In this guide, I will show you how to import .rmesh files exported with CBRE-EX, and all the different import options you can utilize.

> ⚠️ **This addon has only been tested with files exported with CBRE-EX v2.1.0. I don't know how or if it works for files from other versions.**

When Godot detects the .rmesh file, it will try to automatically import it, but it will usually import it with an incorrect importer. What you are interested in when importing CBRE-EX files is "**CBRE-EX RMesh as Mesh**" and "**CBRE-EX RMesh as PackedScene**".

## 2. Importing as Mesh

We'll start with importing the file as a [Mesh](https://docs.godotengine.org/en/stable/classes/class_mesh.html) resource, since that's simpler. Only the room's _mesh_ gets imported, optionally with materials.

When you select "**CBRE-EX RMesh as Mesh**" in the import tab, you will see these categories:

- Mesh
- Materials

---

1. **Mesh category:**

    - Scale Mesh
    
        - A [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html) value representing the scale multiplier of the imported mesh. You usually don't want this to be the default value (1, 1, 1), but lower, as the mesh will be scaled up drastically, since sizes work different in CBRE-EX and in Godot.<br><br>
        
        > ⚠️ **While the values are ratio-locked by default, it is possible to set unusual scale values. However, this is not recommended.**
        
    - Include Invisible Collisions
    
        - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. Some RMesh files have collisions that are invisible. If this value is _true_, they will be included in the imported mesh.<br><br>
        
        > ⚠️ **Due to how Meshes work, the invisible collisions surface will actually be visible, and you will need to make them invisible yourself with a custom Material.**

---

2. **Materials category:**

    - Material Path
    
        - A [String](https://docs.godotengine.org/en/stable/classes/class_string.html) value. An optional path to where the mesh's materials are located. The importer will automatically detect [Material](https://docs.godotengine.org/en/stable/classes/class_material.html) resource .tres files with the same name as the textures in the RMesh file and apply them to their respective surfaces. If the material can't be found, the surface will be without a material.

## 3. Importing as PackedScene

Importing the RMesh as a [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html) allows you to import everything the RMesh file contains, with a ton of options allowing you to select what you want to import.

When you select "**CBRE-EX RMesh as PackedScene**" in the import tab, you will see these categories:

- Mesh
- Collision
- Materials
- Entities

---

1. **Mesh category:**

    - Scale Mesh
    
        - A [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html) value representing the scale multiplier of the imported mesh. You usually don't want this to be the default value (1, 1, 1), but lower, as the mesh will be scaled up drastically, since sizes work different in CBRE-EX and in Godot.

---

2. **Collision category:**

    - Generate Collision Mesh
    
        - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, a single [trimesh collision shape](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html) will be automatically generated for the mesh.
    
    - Include Invisible Collisions
    
        - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. Some RMesh files have collisions that are invisible. If this value is _true_, and "**Generate Collision Mesh**" is also _true_, they will be included in the imported mesh.<br><br>
        
        > ⚠️ **This setting ignores the 'Split Collision Mesh' setting and always generates a separate [StaticBody3D](https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html) for the invisible collisions.**
    
    - Split Collision Mesh
    
        - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If this value is _true_, and "**Generate Collision Mesh**" is also _true_, the mesh's collision will be split up by the mesh's surfaces. For example, if you have 8 surfaces, this option will generate 8 collision shapes.

---

3. **Materials category:**

    - Material Path
    
        - A [String](https://docs.godotengine.org/en/stable/classes/class_string.html) value. An optional path to where the mesh's materials are located. The importer will automatically detect [Material](https://docs.godotengine.org/en/stable/classes/class_material.html) resource .tres files with the same name as the textures in the RMesh file and apply them to their respective surfaces. If the material can't be found, the surface will be without a material.

---

4. **Entities category:**

    - Include entities
    
        - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, entites included in the RMesh file get imported. Each entity type will get put into it's special "folder" [Node](https://docs.godotengine.org/en/stable/classes/class_node.html).
        
            > ⚠️ **While CBRE-EX supports exporting custom entities, importing custom entities is currently not supported. Unexpected things _will_ happen when trying to import an RMesh file with custom entities, as the importer doesn't know what to do with them.**
        
    - **Entity type subcategories:**
    
        - **Lights**
        
            - Include Lights
            
                - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, lights get imported as [OmniLight3D](https://docs.godotengine.org/en/stable/classes/class_omnilight3d.html)s (classname "light" or "spotlight" in the RMesh file).<br><br>
                
                > ⚠️ **CBRE-EX doesn't distinguish between normal lights and spotlights when exporting. All imported lights will always be OmniLight3Ds, never SpotLight3Ds. Also, lighting will always look different with imported lights than how it looks in CBRE-EX. The lights receive values from the RMesh file, but you will have to tweak them more if you want to get them to look the same (or almost the same) as in CBRE-EX.**
            
            - Light Range Scale
            
                - A [float](https://docs.godotengine.org/en/stable/classes/class_float.html) value representing the [OmniLight3D.omni_range](https://docs.godotengine.org/en/stable/classes/class_omnilight3d.html#class-omnilight3d-property-omni-range) property multiplier. It's recommended for this value to be set to the average value of "**Scale Mesh**".
    
        - **Waypoints**
        
            - Include Waypoints
            
                - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, waypoints get imported as [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html)s (classname "waypoint" in the RMesh file).
    
        - **Sound Emitters**
        
            - Include Sound Emitters
            
                - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, sound emitters get imported as [AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html)s (classname "soundemitter" in the RMesh file).<br><br>
            
                > ⚠️ **CBRE-EX uses "sound IDs" to play back sounds through the sound emitters, but since this wouldn't work in Godot by default, this value is not used, and the AudioStreamPlayer3Ds are given no sounds.**
            
            - Sound Range Scale
            
                - A [float](https://docs.godotengine.org/en/stable/classes/class_float.html) value representing the [AudioStreamPlayer3D.max_distance](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html#class-audiostreamplayer3d-property-max-distance) property multiplier.<br><br>
            
                > ⚠️ **This value behaves a bit weird. You'll just have to tweak it and see what works for you.**
    
        - **Models**
        
            - Include Models
            
                - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, models get imported as [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html)s (classname "model" in the RMesh file).<br><br>
                
                > ⚠️ **Currently, only models' positions, rotations and scales get imported as empty Node3Ds with those values, not the models themselves based on their file path.**
    
        - **Screens**
        
            - Include Screens
            
                - A [boolean](https://docs.godotengine.org/en/stable/classes/class_bool.html) value. If _true_, screens get imported as [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html)s (classname "screen" in the RMesh file).<br><br>
                
                > ⚠️ **The screen's "imgpath" property is not used. Only empty Node3Ds get imported.**
        