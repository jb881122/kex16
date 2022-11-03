# KEX16 - Win16 API Compatibility Provider

This project aims to allow some programs written for later versions of 16-bit Windows to run on earlier versions.

## Current Functionality

1. Add support for LB_SETITEMDATA and LB_GETITEMDATA messages

## Development

### How to build

#### Requirements

- A computer or virtual machine running some variant of DOS, preferably MS-DOS 3.30 or similar
- Microsoft Macro Assembler 4.0 (later versions may work)
- Microsoft C 5.1
- Windows 2.x SDK/OAK
- Environment variables:
	- `INCLUDE`: Path to folder with `WINDOWS.H` and `CMACROS.INC`
	- `LIB`: Path to folder with `SLIBW.LIB`
	- `PATH`: Contains the folders with `COMMAND.COM`, `MASM.EXE`, `CL.EXE`, `LINK4.EXE`, and `MAKE.EXE`
- The current directory should be the one containing the source files

#### Commands

- To build: `MAKE KEX16`
- To delete built files: `MAKE CLEAN`

### Adding APIs

While there is no single procedure for adding support for an API function to KEX16, the general steps are as follows:

1. Implement the new API function (usually done in a new source file)
2. Add a check/flag in OSFlags (to turn it off on platforms where it's not needed)
3. Edit the common code (KEX16.C) to add the API function to Windows

## Wishlist

Currently, this project is focused on making programs built for Windows 3.0 run on 2.x. The below additions are in pursuit of that goal. However, if there are new API additions that would increase compatibility with Windows 1.0 or 3.1 applications, those are also welcome.

- Modification of resources on module load to accommodate Windows 2.x's resource format
- MDI support APIs

## File List

- `.gitignore`: Tells git not to include output files
- `README.MD`: This documentation
- `LICENSE`: MIT License
- `KEX16`: Makefile for building
- `CLEAN`: Makefile for removing built files
- `KEX16.DEF`: Defines exports and executable properties
- `KEX16.H`: Definitions used by multiple source files
- `KEX16.C`: Common setup and dispatch code
- `OSFLAGS.C`: Detects underlying OS capabilities
- `LLIST.ASM`: Linked list support routines
- `WINHOOK.ASM`: Routines to hook existing Windows API functions
- `ONLOAD.C`: Modifies modules as they are loaded to ensure compatibility
- `LBITEM.C`: Support for LB_SETITEMDATA and LB_GETITEMDATA messages
