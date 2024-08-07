
###### spent like a week working on this. probably like 4 people asked for it including me lol.

&nbsp;

## Godot 4.2.2 Importer for RoomMesh (.rmesh) files.

Have you ever played [SCP – Containment Breach](https://scpcbgame.com/)? Have you ever thought _"Hmm... I want to get these rooms into Godot, but they're in this weird .rmesh file format."_? If so, then this addon is just the thing you need!

This addon allows you to import this ancient file format officially supported by only one game into the Godot Engine. It supports .rmesh files from the original SCP – Containment Breach game, and also files from [CBRE-EX](https://github.com/AnalogFeelings/cbre-ex), a free third-party map editor for the game.

You can import these room meshes either as Godot's **Mesh** resource, or as a **PackedScene**. The addon includes a multitude of import options, such as **entity importing**, **collision mesh generation** and more.

I highly suggest checking out the addon's [**docs folder**](docs/), as you will find everything about the addon there! (and also some extra stuff..!) You can also just go there from this list.

- [Importing SCP – Containment Breach .rmesh files](docs/importing_scp-cb_files.md)
- [Importing CBRE-EX .rmesh files](docs/importing_cbre-ex_files.md)
- [SCP – Containment Breach RMesh file format](docs/rmesh_format_scp-cb.md)
- [CBRE-EX RMesh file format](docs/rmesh_format_cbre-ex.md)

Now, go wild! **_BUT!_** Read this first:

> ⚠️ **Before you download and install this addon, be aware that I only tested this addon with a few .rmesh files that I selected for both SCP – CB and CBRE-EX. It should technically work with almost all .rmesh files, but exceptions always occur. Please open an [issue](https://github.com/Koanyaku/godot_rmesh_import/issues) if you encounter something unexpected. Also, I created this addon for Godot 4.2.2, and RMesh files from either SCP – Containment Breach v1.3.11 or CBRE-EX v2.1.0, and I don't know how this addon behaves with other Godot versions or RMesh files listed above.**

🌺 By the way, if you found this addon helpful, please consider supporting me by [**buying me a coffee (donating)**](https://ko-fi.com/koanyaku)! I would very much appreciate it. :)