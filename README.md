
###### spent like a week working on this. probably like 4 people asked for it including me lol.

&nbsp;

## Godot 4.2+ Importer for RoomMesh (.rmesh) files.

Have you ever played [SCP – Containment Breach](https://scpcbgame.com/)? Have you ever thought _"Hmm... I want to get these rooms into Godot, but they're in this weird .rmesh file format."_? If so, then this addon is just the thing you need!

This addon allows you to import this ancient file format officially supported by only one game into the Godot Engine. It supports RMesh files from the original SCP – Containment Breach game, and also files from [CBRE-EX](https://github.com/AnalogFeelings/cbre-ex), a free third-party map editor for the game.

### Some features:

- Importing rooms as either Godot's [Mesh](https://docs.godotengine.org/en/stable/classes/class_mesh.html) resource or [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html) resource.
- Automatic collision generation.
- Automatic material application.
- Automatic lightmap application.
- Entity importing.

I highly suggest checking out these links, as you will find all information about the features there!

- [Importing SCP – Containment Breach RMesh files](docs/importing_scp-cb_files.md)
- [Importing CBRE-EX RMesh files](docs/importing_cbre-ex_files.md)<br><br>

Some extra stuff...

- [SCP – Containment Breach RMesh file format](docs/rmesh_format_scp-cb.md)
- [CBRE-EX RMesh file format](docs/rmesh_format_cbre-ex.md)<br><br>

Now, go wild! **_BUT!_** Read this first:

> ⚠️ **This addon should work with all RMesh files, but exceptions always occur. Please open an [issue](https://github.com/Koanyaku/godot_rmesh_import/issues) if you encounter something unexpected. Also, I created this addon for Godot 4.2+, and RMesh files from either SCP – Containment Breach v1.3.11 or CBRE-EX v2.1.0, and I don't know how this addon behaves with other Godot versions or RMesh files listed above.**

🌺 Also, if you want to, you can support me [**here**](https://ko-fi.com/koanyaku). :)