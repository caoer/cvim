# `cvim.editor` — The editing core.
{ lib, ... }:
{
  options.cvim.editor.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      The editing core: syntax, completion, formatting, linting, motions,
      and the text-object/surround family.

      This is the layer every other layer assumes. Turning it off gives you
      nixvim's bare defaults, which is a legitimate thing to want when you are
      bisecting a problem.
    '';
  };
}
