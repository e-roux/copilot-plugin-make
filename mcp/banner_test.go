package main

import "testing"

// Each glyph is exactly 3 chars wide; rows are concatenated without separators.

func TestRenderEmpty(t *testing.T) {
	if got := render(""); got != "" {
		t.Errorf("empty input: want %q, got %q", "", got)
	}
}

func TestRenderSingleLetterA(t *testing.T) {
	want := "╔═╗\n╠═╣\n╝ ╝"
	if got := render("A"); got != want {
		t.Errorf("render(A): want %q, got %q", want, got)
	}
}

func TestRenderLowercaseEqualsUppercase(t *testing.T) {
	if render("make") != render("MAKE") {
		t.Error("lowercase should produce the same output as uppercase")
	}
}

func TestRenderMAKE(t *testing.T) {
	// M  A  K  E concatenated row-by-row
	want := "╔╦╗╔═╗╦╔ ╔═╗\n║║║╠═╣╠╩╗║╣ \n╝ ╝╝ ╝╝ ╝╚═╝"
	if got := render("MAKE"); got != want {
		t.Errorf("render(MAKE):\nwant %q\n got %q", want, got)
	}
}

func TestRenderVFDE(t *testing.T) {
	// V  F  D  E
	want := "╦ ╦╔═╗╔╦╗╔═╗\n║╔╝╠╣  ║║║╣ \n╚╝ ╚  ╚╩╝╚═╝"
	if got := render("VFDE"); got != want {
		t.Errorf("render(VFDE):\nwant %q\n got %q", want, got)
	}
}

func TestRenderSpace(t *testing.T) {
	want := "   \n   \n   "
	if got := render(" "); got != want {
		t.Errorf("render( ): want %q, got %q", want, got)
	}
}

func TestRenderUnknownCharFallsBackToSpace(t *testing.T) {
	// Unknown chars should not panic and should fall back to a space glyph
	got := render("?")
	if got == "" {
		t.Error("render(?) should return three non-empty rows (space fallback)")
	}
}

func TestRenderMultipleSpaces(t *testing.T) {
	one := render(" ")
	two := render("  ")
	if len(two) <= len(one) {
		t.Error("two spaces should produce wider output than one space")
	}
}

func TestRenderOutputHasExactlyTwoNewlines(t *testing.T) {
	for _, word := range []string{"A", "MAKE", "VFDE", "GO"} {
		got := render(word)
		count := 0
		for _, ch := range got {
			if ch == '\n' {
				count++
			}
		}
		if count != 2 {
			t.Errorf("render(%q): expected exactly 2 newlines, got %d", word, count)
		}
	}
}
