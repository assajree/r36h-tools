/*
 * setup_ui.c - Universal ncurses-style Dialog Setup UI Engine (Direct SDL2 KMSDRM)
 *
 * Renders an authentic Linux ncurses `dialog` TUI (blue backdrop, 3D raised gray
 * dialog window with black drop shadow, centered title, 3D sunken option list box,
 * 3D gauge progress bar, and < OK > < Back > < Exit > buttons) directly to the
 * R36H KMSDRM display via SDL2 so it works 100% inside both EmulationStation
 * (TOOLS menu) and playOS Terminal (FindManager).
 *
 * Controls (Hardware Gamepad + Keyboard):
 *   - D-Pad UP / DOWN (or Analog Y)    : Highlight Option ([X] Option 1..N)
 *   - D-Pad LEFT / RIGHT (or Analog X) : Highlight Action Button (< OK > / < Back > / < Exit >)
 *   - Button A OR Button B (or Enter)  : Trigger Focused Action Button
 */

#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <linux/input.h>

#define SCREEN_W 640
#define SCREEN_H 480

/* Authentic Linux ncurses `dialog` Color Palette */
#define BG_SCREEN_R  0
#define BG_SCREEN_G  68
#define BG_SCREEN_B  170

#define DLG_GRAY_R   184
#define DLG_GRAY_G   188
#define DLG_GRAY_B   194

#define DLG_LIGHT_R  250
#define DLG_LIGHT_G  252
#define DLG_LIGHT_B  255

#define DLG_DARK_R   58
#define DLG_DARK_G   62
#define DLG_DARK_B   68

#define SHADOW_R     0
#define SHADOW_G     0
#define SHADOW_B     0

#define HL_NAVY_R    0
#define HL_NAVY_G    52
#define HL_NAVY_B    168

#define FG_WHITE_R   255
#define FG_WHITE_G   255
#define FG_WHITE_B   255

#define FG_BLACK_R   18
#define FG_BLACK_G   20
#define FG_BLACK_B   24

#define FG_NAVY_R    0
#define FG_NAVY_G    42
#define FG_NAVY_B    150

#define FG_YELLOW_R  255
#define FG_YELLOW_G  238
#define FG_YELLOW_B  58

#define FG_CYAN_R    130
#define FG_CYAN_G    235
#define FG_CYAN_B    255

#define FG_MUTED_R   122
#define FG_MUTED_G   126
#define FG_MUTED_B   132

/* Standard 8x8 ASCII bitmap font (32..126) */
static const unsigned char font8x8_basic[95][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /* 32 ' ' */
    {0x18,0x3C,0x3C,0x18,0x18,0x00,0x18,0x00}, /* 33 '!' */
    {0x36,0x36,0x00,0x00,0x00,0x00,0x00,0x00}, /* 34 '"' */
    {0x36,0x36,0x7F,0x36,0x7F,0x36,0x36,0x00}, /* 35 '#' */
    {0x0C,0x3E,0x03,0x1E,0x30,0x1F,0x0C,0x00}, /* 36 '$' */
    {0x00,0x63,0x33,0x18,0x0C,0x66,0x63,0x00}, /* 37 '%' */
    {0x1C,0x36,0x1C,0x6E,0x3B,0x33,0x6E,0x00}, /* 38 '&' */
    {0x06,0x06,0x03,0x00,0x00,0x00,0x00,0x00}, /* 39 ''' */
    {0x18,0x0C,0x06,0x06,0x06,0x0C,0x18,0x00}, /* 40 '(' */
    {0x06,0x0C,0x18,0x18,0x18,0x0C,0x06,0x00}, /* 41 ')' */
    {0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00}, /* 42 '*' */
    {0x00,0x0C,0x0C,0x3F,0x0C,0x0C,0x00,0x00}, /* 43 '+' */
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x06}, /* 44 ',' */
    {0x00,0x00,0x00,0x3F,0x00,0x00,0x00,0x00}, /* 45 '-' */
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x00}, /* 46 '.' */
    {0x60,0x30,0x18,0x0C,0x06,0x03,0x01,0x00}, /* 47 '/' */
    {0x3E,0x63,0x73,0x7B,0x6F,0x67,0x3E,0x00}, /* 48 '0' */
    {0x0C,0x0E,0x0C,0x0C,0x0C,0x0C,0x3F,0x00}, /* 49 '1' */
    {0x1E,0x33,0x30,0x1C,0x06,0x33,0x3F,0x00}, /* 50 '2' */
    {0x1E,0x33,0x30,0x1C,0x30,0x33,0x1E,0x00}, /* 51 '3' */
    {0x38,0x3C,0x36,0x33,0x7F,0x30,0x78,0x00}, /* 52 '4' */
    {0x3F,0x03,0x1F,0x30,0x30,0x33,0x1E,0x00}, /* 53 '5' */
    {0x1C,0x06,0x03,0x1F,0x33,0x33,0x1E,0x00}, /* 54 '6' */
    {0x3F,0x33,0x30,0x18,0x0C,0x0C,0x0C,0x00}, /* 55 '7' */
    {0x1E,0x33,0x33,0x1E,0x33,0x33,0x1E,0x00}, /* 56 '8' */
    {0x1E,0x33,0x33,0x3E,0x30,0x18,0x0E,0x00}, /* 57 '9' */
    {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x00}, /* 58 ':' */
    {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x06}, /* 59 ';' */
    {0x18,0x0C,0x06,0x03,0x06,0x0C,0x18,0x00}, /* 60 '<' */
    {0x00,0x00,0x3F,0x00,0x00,0x3F,0x00,0x00}, /* 61 '=' */
    {0x06,0x0C,0x18,0x30,0x18,0x0C,0x06,0x00}, /* 62 '>' */
    {0x1E,0x33,0x30,0x18,0x0C,0x00,0x0C,0x00}, /* 63 '?' */
    {0x3E,0x63,0x7B,0x7B,0x7B,0x03,0x1E,0x00}, /* 64 '@' */
    {0x0C,0x1E,0x33,0x33,0x3F,0x33,0x33,0x00}, /* 65 'A' */
    {0x3F,0x66,0x66,0x3E,0x66,0x66,0x3F,0x00}, /* 66 'B' */
    {0x3C,0x66,0x03,0x03,0x03,0x66,0x3C,0x00}, /* 67 'C' */
    {0x1F,0x36,0x66,0x66,0x66,0x36,0x1F,0x00}, /* 68 'D' */
    {0x7F,0x46,0x16,0x1E,0x16,0x46,0x7F,0x00}, /* 69 'E' */
    {0x7F,0x46,0x16,0x1E,0x16,0x06,0x0F,0x00}, /* 70 'F' */
    {0x3C,0x66,0x03,0x03,0x73,0x66,0x7C,0x00}, /* 71 'G' */
    {0x33,0x33,0x33,0x3F,0x33,0x33,0x33,0x00}, /* 72 'H' */
    {0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, /* 73 'I' */
    {0x78,0x30,0x30,0x30,0x33,0x33,0x1E,0x00}, /* 74 'J' */
    {0x67,0x66,0x36,0x1E,0x36,0x66,0x67,0x00}, /* 75 'K' */
    {0x0F,0x06,0x06,0x06,0x46,0x66,0x7F,0x00}, /* 76 'L' */
    {0x63,0x77,0x7F,0x7F,0x6B,0x63,0x63,0x00}, /* 77 'M' */
    {0x63,0x67,0x6F,0x7B,0x73,0x63,0x63,0x00}, /* 78 'N' */
    {0x1C,0x36,0x63,0x63,0x63,0x36,0x1C,0x00}, /* 79 'O' */
    {0x3F,0x66,0x66,0x3E,0x06,0x06,0x0F,0x00}, /* 80 'P' */
    {0x1E,0x33,0x33,0x33,0x3B,0x1E,0x38,0x00}, /* 81 'Q' */
    {0x3F,0x66,0x66,0x3E,0x36,0x66,0x67,0x00}, /* 82 'R' */
    {0x1E,0x33,0x07,0x0E,0x38,0x33,0x1E,0x00}, /* 83 'S' */
    {0x3F,0x2D,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, /* 84 'T' */
    {0x33,0x33,0x33,0x33,0x33,0x33,0x3F,0x00}, /* 85 'U' */
    {0x33,0x33,0x33,0x33,0x33,0x1E,0x0C,0x00}, /* 86 'V' */
    {0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00}, /* 87 'W' */
    {0x63,0x63,0x36,0x1C,0x1C,0x36,0x63,0x00}, /* 88 'X' */
    {0x33,0x33,0x33,0x1E,0x0C,0x0C,0x1E,0x00}, /* 89 'Y' */
    {0x7F,0x63,0x31,0x18,0x4C,0x66,0x7F,0x00}, /* 90 'Z' */
    {0x1E,0x06,0x06,0x06,0x06,0x06,0x1E,0x00}, /* 91 '[' */
    {0x03,0x06,0x0C,0x18,0x30,0x60,0x40,0x00}, /* 92 '\' */
    {0x1E,0x18,0x18,0x18,0x18,0x18,0x1E,0x00}, /* 93 ']' */
    {0x08,0x1C,0x36,0x63,0x00,0x00,0x00,0x00}, /* 94 '^' */
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF}, /* 95 '_' */
    {0x0C,0x0C,0x18,0x00,0x00,0x00,0x00,0x00}, /* 96 '`' */
    {0x00,0x00,0x1E,0x30,0x3E,0x33,0x6E,0x00}, /* 97 'a' */
    {0x07,0x06,0x06,0x3E,0x66,0x66,0x3B,0x00}, /* 98 'b' */
    {0x00,0x00,0x1E,0x33,0x03,0x33,0x1E,0x00}, /* 99 'c' */
    {0x38,0x30,0x30,0x3e,0x33,0x33,0x6E,0x00}, /* 100 'd' */
    {0x00,0x00,0x1E,0x33,0x3f,0x03,0x1E,0x00}, /* 101 'e' */
    {0x1C,0x36,0x06,0x0f,0x06,0x06,0x0F,0x00}, /* 102 'f' */
    {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x1F}, /* 103 'g' */
    {0x07,0x06,0x36,0x6E,0x66,0x66,0x67,0x00}, /* 104 'h' */
    {0x0C,0x00,0x0E,0x0C,0x0C,0x0C,0x1E,0x00}, /* 105 'i' */
    {0x30,0x00,0x30,0x30,0x30,0x33,0x33,0x1E}, /* 106 'j' */
    {0x07,0x06,0x66,0x36,0x1E,0x36,0x67,0x00}, /* 107 'k' */
    {0x0E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, /* 108 'l' */
    {0x00,0x00,0x33,0x7F,0x7F,0x6B,0x63,0x00}, /* 109 'm' */
    {0x00,0x00,0x1F,0x33,0x33,0x33,0x33,0x00}, /* 110 'n' */
    {0x00,0x00,0x1E,0x33,0x33,0x33,0x1E,0x00}, /* 111 'o' */
    {0x00,0x00,0x3B,0x66,0x66,0x3E,0x06,0x0F}, /* 112 'p' */
    {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x78}, /* 113 'q' */
    {0x00,0x00,0x3B,0x6E,0x66,0x06,0x0F,0x00}, /* 114 'r' */
    {0x00,0x00,0x3E,0x03,0x1E,0x30,0x1F,0x00}, /* 115 's' */
    {0x08,0x0C,0x3E,0x0C,0x0C,0x2C,0x18,0x00}, /* 116 't' */
    {0x00,0x00,0x33,0x33,0x33,0x33,0x6E,0x00}, /* 117 'u' */
    {0x00,0x00,0x33,0x33,0x33,0x1E,0x0C,0x00}, /* 118 'v' */
    {0x00,0x00,0x63,0x6B,0x7F,0x7F,0x36,0x00}, /* 119 'w' */
    {0x00,0x00,0x63,0x36,0x1C,0x36,0x63,0x00}, /* 120 'x' */
    {0x00,0x00,0x33,0x33,0x33,0x3E,0x30,0x1F}, /* 121 'y' */
    {0x00,0x00,0x3F,0x19,0x0C,0x26,0x3F,0x00}, /* 122 'z' */
    {0x38,0x0C,0x0C,0x07,0x0C,0x0C,0x38,0x00}, /* 123 '{' */
    {0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00}, /* 124 '|' */
    {0x07,0x0C,0x0C,0x38,0x0C,0x0C,0x07,0x00}, /* 125 '}' */
    {0x6E,0x3B,0x00,0x00,0x00,0x00,0x00,0x00}  /* 126 '~' */
};

/* Configuration Data Structures */
#define MAX_PAGES      16
#define MAX_OPTIONS    8
#define MAX_PROGRESS   8
#define MAX_STEPS      20
#define MAX_COMP_LINES 8
#define MAX_STR        256
#define MAX_CMD        1024

typedef struct {
    char value[64];
    char next_target[64]; /* "next", "page:<id>", "run:<id>", "quit" */
    char label[MAX_STR];
    char desc[MAX_STR];
} WizardOption;

typedef struct {
    char id[64];
    char title[MAX_STR];  /* Dialog Title (Step Name) */
    char var[64];
    int default_idx;
    int selected_idx;
    int num_options;
    WizardOption options[MAX_OPTIONS];
} WizardPage;

typedef struct {
    int target_pct;
    char status[MAX_STR];
    char cmd[MAX_CMD];
} ProgressStep;

typedef struct {
    char id[64];
    char line1[MAX_STR];
    char line2[MAX_STR];
    char line3[MAX_STR];
    char box_title[MAX_STR];
    int num_steps;
    ProgressStep steps[MAX_STEPS];
    char complete_title[MAX_STR];
    int num_complete_lines;
    char complete_lines[MAX_COMP_LINES][MAX_STR];
} ProgressFlow;

typedef struct {
    char header[MAX_STR];
    int num_pages;
    WizardPage pages[MAX_PAGES];
    int num_progress;
    ProgressFlow flows[MAX_PROGRESS];
} SetupConfig;

static SetupConfig g_cfg;

/* String Utilities */
static char *trim_ws(char *s) {
    while (*s && isspace((unsigned char)*s)) s++;
    if (*s == '\0') return s;
    char *end = s + strlen(s) - 1;
    while (end > s && isspace((unsigned char)*end)) {
        *end = '\0';
        end--;
    }
    return s;
}

static void safe_copy(char *dst, const char *src, size_t dst_size) {
    if (!src) {
        dst[0] = '\0';
        return;
    }
    strncpy(dst, src, dst_size - 1);
    dst[dst_size - 1] = '\0';
}

/* Expand $VAR or ${VAR} from environment */
static void expand_vars(const char *src, char *dst, size_t dst_size) {
    size_t di = 0;
    const char *p = src;
    while (*p && di + 1 < dst_size) {
        if (*p == '$') {
            p++;
            char vname[64];
            size_t vi = 0;
            int braced = 0;
            if (*p == '{') {
                braced = 1;
                p++;
            }
            while (*p && (isalnum((unsigned char)*p) || *p == '_') && vi + 1 < sizeof(vname)) {
                vname[vi++] = *p++;
            }
            vname[vi] = '\0';
            if (braced && *p == '}') p++;

            if (vi > 0) {
                const char *val = getenv(vname);
                if (val) {
                    while (*val && di + 1 < dst_size) {
                        dst[di++] = *val++;
                    }
                }
            } else {
                dst[di++] = '$';
            }
        } else {
            dst[di++] = *p++;
        }
    }
    dst[di] = '\0';
}

static int split_pipe_fields(char *line, char *fields[], int max_fields) {
    int count = 0;
    char *cur = line;
    while (cur && count < max_fields) {
        if (count == max_fields - 1) {
            fields[count++] = trim_ws(cur);
            break;
        }
        char *bar = strchr(cur, '|');
        if (bar) {
            *bar = '\0';
            fields[count++] = trim_ws(cur);
            cur = bar + 1;
        } else {
            fields[count++] = trim_ws(cur);
            break;
        }
    }
    return count;
}

static void parse_config_stream(FILE *fp) {
    memset(&g_cfg, 0, sizeof(g_cfg));
    safe_copy(g_cfg.header, "playOS Setup Utility", sizeof(g_cfg.header));

    int section_type = 0; /* 0 = global, 1 = [page], 2 = [progress] */
    WizardPage *cur_page = NULL;
    ProgressFlow *cur_flow = NULL;

    char line_buf[2048];
    while (fgets(line_buf, sizeof(line_buf), fp)) {
        char *line = trim_ws(line_buf);
        if (line[0] == '\0' || line[0] == '#') continue;

        if (strcmp(line, "[page]") == 0) {
            if (g_cfg.num_pages < MAX_PAGES) {
                cur_page = &g_cfg.pages[g_cfg.num_pages++];
                memset(cur_page, 0, sizeof(*cur_page));
                section_type = 1;
            }
            continue;
        } else if (strcmp(line, "[progress]") == 0) {
            if (g_cfg.num_progress < MAX_PROGRESS) {
                cur_flow = &g_cfg.flows[g_cfg.num_progress++];
                memset(cur_flow, 0, sizeof(*cur_flow));
                safe_copy(cur_flow->box_title, "Setup Progress", sizeof(cur_flow->box_title));
                safe_copy(cur_flow->complete_title, "Setup Complete", sizeof(cur_flow->complete_title));
                section_type = 2;
            }
            continue;
        }

        char *eq = strchr(line, '=');
        if (!eq) continue;
        *eq = '\0';
        char *key = trim_ws(line);
        char *val = trim_ws(eq + 1);

        if (section_type == 0) {
            if (strcmp(key, "header") == 0) {
                safe_copy(g_cfg.header, val, sizeof(g_cfg.header));
            }
        } else if (section_type == 1 && cur_page) {
            if (strcmp(key, "id") == 0) safe_copy(cur_page->id, val, sizeof(cur_page->id));
            else if (strcmp(key, "title") == 0 || strcmp(key, "step_name") == 0) safe_copy(cur_page->title, val, sizeof(cur_page->title));
            else if (strcmp(key, "var") == 0) safe_copy(cur_page->var, val, sizeof(cur_page->var));
            else if (strcmp(key, "default") == 0) {
                cur_page->default_idx = atoi(val);
                cur_page->selected_idx = cur_page->default_idx;
            } else if (strcmp(key, "option") == 0 && cur_page->num_options < MAX_OPTIONS) {
                char *f[5] = {NULL};
                int nf = split_pipe_fields(val, f, 5);
                if (nf >= 3) {
                    WizardOption *opt = &cur_page->options[cur_page->num_options++];
                    safe_copy(opt->value, f[0], sizeof(opt->value));
                    safe_copy(opt->next_target, f[1], sizeof(opt->next_target));
                    safe_copy(opt->label, f[2], sizeof(opt->label));
                    if (nf >= 4) safe_copy(opt->desc, f[3], sizeof(opt->desc));
                }
            }
        } else if (section_type == 2 && cur_flow) {
            if (strcmp(key, "id") == 0) safe_copy(cur_flow->id, val, sizeof(cur_flow->id));
            else if (strcmp(key, "line1") == 0) safe_copy(cur_flow->line1, val, sizeof(cur_flow->line1));
            else if (strcmp(key, "line2") == 0) safe_copy(cur_flow->line2, val, sizeof(cur_flow->line2));
            else if (strcmp(key, "line3") == 0) safe_copy(cur_flow->line3, val, sizeof(cur_flow->line3));
            else if (strcmp(key, "box_title") == 0) safe_copy(cur_flow->box_title, val, sizeof(cur_flow->box_title));
            else if (strcmp(key, "complete_title") == 0) safe_copy(cur_flow->complete_title, val, sizeof(cur_flow->complete_title));
            else if (strcmp(key, "complete_line") == 0 && cur_flow->num_complete_lines < MAX_COMP_LINES) {
                safe_copy(cur_flow->complete_lines[cur_flow->num_complete_lines++], val, MAX_STR);
            } else if (strcmp(key, "step") == 0 && cur_flow->num_steps < MAX_STEPS) {
                char *f[3] = {NULL};
                int nf = split_pipe_fields(val, f, 3);
                if (nf >= 2) {
                    ProgressStep *st = &cur_flow->steps[cur_flow->num_steps++];
                    st->target_pct = atoi(f[0]);
                    safe_copy(st->status, f[1], sizeof(st->status));
                    if (nf >= 3) safe_copy(st->cmd, f[2], sizeof(st->cmd));
                }
            }
        }
    }
}

/* Font & Primitive Rendering (LSB-first bit order for font8x8_basic) */
static void draw_char(SDL_Renderer *rend, int x, int y, char c, int scale_x, int scale_y) {
    if (c < 32 || c > 126) c = ' ';
    const unsigned char *glyph = font8x8_basic[c - 32];
    for (int row = 0; row < 8; row++) {
        unsigned char bits = glyph[row];
        for (int col = 0; col < 8; col++) {
            if (bits & (1 << col)) {
                SDL_Rect r = { x + col * scale_x, y + row * scale_y, scale_x, scale_y };
                SDL_RenderFillRect(rend, &r);
            }
        }
    }
}

/* Bold 16x16 text (scale_x=2, scale_y=2) */
static void draw_bold_text(SDL_Renderer *rend, int x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    SDL_SetRenderDrawColor(rend, r, g, b, 255);
    int cur_x = x;
    while (*str) {
        draw_char(rend, cur_x, y, *str, 2, 2);
        cur_x += 16;
        str++;
    }
}

/* Standard 8x16 VGA terminal text (scale_x=1, scale_y=2) */
static void draw_vga_text(SDL_Renderer *rend, int x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    SDL_SetRenderDrawColor(rend, r, g, b, 255);
    int cur_x = x;
    while (*str) {
        draw_char(rend, cur_x, y, *str, 1, 2);
        cur_x += 8;
        str++;
    }
}

/* Faux-Bold 8x16 VGA text (double-struck by 1px for crisp ncurses readability) */
static void draw_vga_bold(SDL_Renderer *rend, int x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    draw_vga_text(rend, x, y, str, r, g, b);
    draw_vga_text(rend, x + 1, y, str, r, g, b);
}

static void draw_vga_centered(SDL_Renderer *rend, int center_x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    int w = (int)strlen(str) * 8;
    draw_vga_text(rend, center_x - (w / 2), y, str, r, g, b);
}

static void draw_vga_bold_centered(SDL_Renderer *rend, int center_x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    int w = (int)strlen(str) * 8;
    draw_vga_bold(rend, center_x - (w / 2), y, str, r, g, b);
}

/* Draw a 3D Beveled Box (raised=1: white top/left, dark bottom/right; raised=0: sunken) */
static void draw_3d_bevel(SDL_Renderer *rend, int x, int y, int w, int h, int raised) {
    Uint8 tl_r = raised ? DLG_LIGHT_R : DLG_DARK_R;
    Uint8 tl_g = raised ? DLG_LIGHT_G : DLG_DARK_G;
    Uint8 tl_b = raised ? DLG_LIGHT_B : DLG_DARK_B;

    Uint8 br_r = raised ? DLG_DARK_R : DLG_LIGHT_R;
    Uint8 br_g = raised ? DLG_DARK_G : DLG_LIGHT_G;
    Uint8 br_b = raised ? DLG_DARK_B : DLG_LIGHT_B;

    /* Top & Left (2px thick) */
    SDL_SetRenderDrawColor(rend, tl_r, tl_g, tl_b, 255);
    SDL_Rect top_bar = { x, y, w, 2 };
    SDL_Rect left_bar = { x, y, 2, h };
    SDL_RenderFillRect(rend, &top_bar);
    SDL_RenderFillRect(rend, &left_bar);

    /* Bottom & Right (2px thick) */
    SDL_SetRenderDrawColor(rend, br_r, br_g, br_b, 255);
    SDL_Rect bot_bar = { x, y + h - 2, w, 2 };
    SDL_Rect right_bar = { x + w - 2, y, 2, h };
    SDL_RenderFillRect(rend, &bot_bar);
    SDL_RenderFillRect(rend, &right_bar);
}

/* Draw the ncurses blue screen backdrop, top `--backtitle`, and 3D gray dialog window */
static void draw_ncurses_window(SDL_Renderer *rend, int dx, int dy, int dw, int dh, const char *dlg_title) {
    char hdr_exp[MAX_STR];
    expand_vars(g_cfg.header, hdr_exp, sizeof(hdr_exp));

    /* 1. Classic ncurses Blue Screen Background */
    SDL_SetRenderDrawColor(rend, BG_SCREEN_R, BG_SCREEN_G, BG_SCREEN_B, 255);
    SDL_RenderClear(rend);

    /* 2. Top-left `--backtitle` + Horizontal Rule across top */
    draw_vga_bold(rend, 16, 10, hdr_exp, FG_CYAN_R, FG_CYAN_G, FG_CYAN_B);
    SDL_SetRenderDrawColor(rend, FG_CYAN_R, FG_CYAN_G, FG_CYAN_B, 255);
    SDL_Rect back_hr = { 16, 32, SCREEN_W - 32, 2 };
    SDL_RenderFillRect(rend, &back_hr);

    /* 3. Black Drop Shadow offset (+12px right, +12px down) */
    SDL_SetRenderDrawColor(rend, SHADOW_R, SHADOW_G, SHADOW_B, 255);
    SDL_Rect shadow = { dx + 12, dy + 12, dw, dh };
    SDL_RenderFillRect(rend, &shadow);

    /* 4. Light Gray Dialog Window Surface */
    SDL_SetRenderDrawColor(rend, DLG_GRAY_R, DLG_GRAY_G, DLG_GRAY_B, 255);
    SDL_Rect box = { dx, dy, dw, dh };
    SDL_RenderFillRect(rend, &box);

    /* 5. Outer 3D Raised Frame (inset by 8px, like ncurses dialog box border) */
    int fx = dx + 8;
    int fy = dy + 10;
    int fw = dw - 16;
    int fh = dh - 18;
    draw_3d_bevel(rend, fx, fy, fw, fh, 1);

    /* 6. Centered Dialog `--title` sitting on the top border */
    if (dlg_title && dlg_title[0] != '\0') {
        char title_exp[MAX_STR];
        expand_vars(dlg_title, title_exp, sizeof(title_exp));
        int tw = ((int)strlen(title_exp) + 2) * 8;
        int tx = dx + (dw - tw) / 2;

        SDL_SetRenderDrawColor(rend, DLG_GRAY_R, DLG_GRAY_G, DLG_GRAY_B, 255);
        SDL_Rect tpad = { tx - 4, fy - 7, tw + 8, 18 };
        SDL_RenderFillRect(rend, &tpad);

        char bracketed[MAX_STR + 8];
        snprintf(bracketed, sizeof(bracketed), " %s ", title_exp);
        draw_vga_bold(rend, tx, fy - 7, bracketed, FG_NAVY_R, FG_NAVY_G, FG_NAVY_B);
    }

    /* 7. Bottom Footer Hint on Blue Screen */
    draw_vga_centered(rend, 320, 456, "UP/DOWN: Select Option   LEFT/RIGHT: Select Button   A/B: Confirm", FG_CYAN_R, FG_CYAN_G, FG_CYAN_B);
}

/* Draw an ncurses `<  OK  >` / `< Back >` / `< Exit >` Button */
static void draw_ncurses_button(SDL_Renderer *rend, int x, int y, int w, int h, const char *label, int is_focused, int is_disabled) {
    char btn_text[32];
    snprintf(btn_text, sizeof(btn_text), "< %s >", label);
    int text_w = (int)strlen(btn_text) * 16;
    int text_x = x + (w - text_w) / 2;
    int text_y = y + (h - 16) / 2;

    if (is_disabled) {
        draw_bold_text(rend, text_x, text_y, btn_text, FG_MUTED_R, FG_MUTED_G, FG_MUTED_B);
    } else if (is_focused) {
        /* Active ncurses Button: Navy Fill + 3D Raised Bevel + White `< >` + Yellow Label */
        SDL_SetRenderDrawColor(rend, HL_NAVY_R, HL_NAVY_G, HL_NAVY_B, 255);
        SDL_Rect fill = { x, y, w, h };
        SDL_RenderFillRect(rend, &fill);
        draw_3d_bevel(rend, x, y, w, h, 1);

        draw_bold_text(rend, text_x, text_y, "<", FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
        draw_bold_text(rend, text_x + 32, text_y, label, FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B);
        draw_bold_text(rend, text_x + text_w - 16, text_y, ">", FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
    } else {
        /* Unfocused Enabled Button: `< Label >` in Black on Gray */
        draw_bold_text(rend, text_x, text_y, btn_text, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);
    }
}

/* Input Handling: UP/DOWN = Option, LEFT/RIGHT = Action Button, A or B = Trigger */
typedef enum {
    ACT_NONE = 0,
    ACT_UP,
    ACT_DOWN,
    ACT_LEFT,
    ACT_RIGHT,
    ACT_TRIGGER
} InputAction;

static int ev_fds[16];
static int num_ev_fds = 0;
static int axis_x_state = 0;
static int axis_y_state = 0;

static void open_evdev_inputs(void) {
    glob_t g;
    if (glob("/dev/input/event*", 0, NULL, &g) == 0) {
        for (size_t i = 0; i < g.gl_pathc && num_ev_fds < 16; i++) {
            int fd = open(g.gl_pathv[i], O_RDONLY | O_NONBLOCK);
            if (fd >= 0) {
                ev_fds[num_ev_fds++] = fd;
            }
        }
        globfree(&g);
    }
}

static void close_evdev_inputs(void) {
    for (int i = 0; i < num_ev_fds; i++) {
        close(ev_fds[i]);
    }
    num_ev_fds = 0;
}

static void drain_all_inputs(void) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {}
    struct input_event ie;
    for (int i = 0; i < num_ev_fds; i++) {
        while (read(ev_fds[i], &ie, sizeof(ie)) > 0) {}
    }
}

static InputAction poll_user_action(void) {
    InputAction act = ACT_NONE;

    struct input_event ie;
    for (int i = 0; i < num_ev_fds; i++) {
        while (read(ev_fds[i], &ie, sizeof(ie)) == sizeof(ie)) {
            if (ie.type == EV_KEY && ie.value == 1) {
                if (ie.code == 544 || ie.code == 103) { /* D-Pad UP / KEY_UP */
                    act = ACT_UP;
                } else if (ie.code == 545 || ie.code == 108) { /* D-Pad DOWN / KEY_DOWN */
                    act = ACT_DOWN;
                } else if (ie.code == 546 || ie.code == 105) { /* D-Pad LEFT / KEY_LEFT */
                    act = ACT_LEFT;
                } else if (ie.code == 547 || ie.code == 106) { /* D-Pad RIGHT / KEY_RIGHT */
                    act = ACT_RIGHT;
                } else if (ie.code == 304 || ie.code == 305 || ie.code == 705 || ie.code == 28) {
                    /* Either A (305) or B (304) or START (705) or ENTER (28) triggers! */
                    act = ACT_TRIGGER;
                }
            } else if (ie.type == EV_ABS) {
                /* Vertical Axis (ABS_Y = 1 or ABS_HAT0Y = 17) */
                if (ie.code == 1 || ie.code == 17) {
                    if (ie.value <= -600 || (ie.code == 17 && ie.value < 0)) {
                        if (axis_y_state != -1) {
                            axis_y_state = -1;
                            act = ACT_UP;
                        }
                    } else if (ie.value >= 600 || (ie.code == 17 && ie.value > 0)) {
                        if (axis_y_state != 1) {
                            axis_y_state = 1;
                            act = ACT_DOWN;
                        }
                    } else if (ie.value > -300 && ie.value < 300) {
                        axis_y_state = 0;
                    }
                }
                /* Horizontal Axis (ABS_X = 0 or ABS_HAT0X = 16) */
                else if (ie.code == 0 || ie.code == 16) {
                    if (ie.value <= -600 || (ie.code == 16 && ie.value < 0)) {
                        if (axis_x_state != -1) {
                            axis_x_state = -1;
                            act = ACT_LEFT;
                        }
                    } else if (ie.value >= 600 || (ie.code == 16 && ie.value > 0)) {
                        if (axis_x_state != 1) {
                            axis_x_state = 1;
                            act = ACT_RIGHT;
                        }
                    } else if (ie.value > -300 && ie.value < 300) {
                        axis_x_state = 0;
                    }
                }
            }
        }
    }

    SDL_Event sev;
    while (SDL_PollEvent(&sev)) {
        if (sev.type == SDL_KEYDOWN) {
            if (sev.key.keysym.sym == SDLK_UP) act = ACT_UP;
            else if (sev.key.keysym.sym == SDLK_DOWN) act = ACT_DOWN;
            else if (sev.key.keysym.sym == SDLK_LEFT) act = ACT_LEFT;
            else if (sev.key.keysym.sym == SDLK_RIGHT) act = ACT_RIGHT;
            else if (sev.key.keysym.sym == SDLK_RETURN || sev.key.keysym.sym == SDLK_SPACE) act = ACT_TRIGGER;
        }
    }

    return act;
}

/* Render Wizard Page inside the 3D ncurses Dialog Window */
static void render_wizard_page(SDL_Renderer *rend, WizardPage *page, int action_idx, int can_go_back) {
    int dx = 34, dy = 52, dw = 560, dh = 384;
    draw_ncurses_window(rend, dx, dy, dw, dh, page->title);

    char buf[MAX_STR];
    int n = page->num_options;

    /* Selected option description above the sunken list box */
    if (n > 0 && page->options[page->selected_idx].desc[0] != '\0') {
        expand_vars(page->options[page->selected_idx].desc, buf, sizeof(buf));
        draw_vga_bold(rend, dx + 26, dy + 32, buf, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);
    } else {
        draw_vga_bold(rend, dx + 26, dy + 32, "Use UP/DOWN to select an option, then press OK:", FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);
    }

    /* Sunken 3D Inner Box for the Options List (like dialog --radiolist) */
    int sx = dx + 26;
    int sy = dy + 64;
    int sw = dw - 52;
    int sh = 224;
    draw_3d_bevel(rend, sx, sy, sw, sh, 0); /* raised = 0 (sunken) */

    int start_y = sy + 16;
    int row_step = 40;

    for (int i = 0; i < n; i++) {
        int y = start_y + (i * row_step);
        char opt_label[MAX_STR];
        expand_vars(page->options[i].label, opt_label, sizeof(opt_label));

        if (i == page->selected_idx) {
            /* Highlight Bar inside Sunken Box */
            SDL_SetRenderDrawColor(rend, HL_NAVY_R, HL_NAVY_G, HL_NAVY_B, 255);
            SDL_Rect hl = { sx + 6, y - 6, sw - 12, 30 };
            SDL_RenderFillRect(rend, &hl);

            draw_bold_text(rend, sx + 14, y, "[X]", FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B);
            draw_bold_text(rend, sx + 78, y, opt_label, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
        } else {
            draw_bold_text(rend, sx + 14, y, "[ ]", FG_NAVY_R, FG_NAVY_G, FG_NAVY_B);
            draw_bold_text(rend, sx + 78, y, opt_label, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);
        }
    }

    /* 3D Horizontal Divider above the Action Buttons */
    int div_y = dy + 308;
    SDL_SetRenderDrawColor(rend, DLG_DARK_R, DLG_DARK_G, DLG_DARK_B, 255);
    SDL_Rect div_top = { dx + 10, div_y, dw - 20, 2 };
    SDL_RenderFillRect(rend, &div_top);
    SDL_SetRenderDrawColor(rend, DLG_LIGHT_R, DLG_LIGHT_G, DLG_LIGHT_B, 255);
    SDL_Rect div_bot = { dx + 10, div_y + 2, dw - 20, 2 };
    SDL_RenderFillRect(rend, &div_bot);

    /* Bottom Action Buttons: < OK >  < Back >  < Exit > */
    int btn_y = dy + 324;
    int btn_h = 38;
    draw_ncurses_button(rend, dx + 54,  btn_y, 136, btn_h, "OK",   action_idx == 0, 0);
    draw_ncurses_button(rend, dx + 212, btn_y, 136, btn_h, "Back", action_idx == 1, !can_go_back);
    draw_ncurses_button(rend, dx + 370, btn_y, 136, btn_h, "Exit", action_idx == 2, 0);

    SDL_RenderPresent(rend);
}

/* Render Progress Bar Screen (`dialog --gauge`) */
static void render_progress_flow(SDL_Renderer *rend, ProgressFlow *flow, int pct, const char *status_str) {
    int dx = 44, dy = 86, dw = 540, dh = 280;
    draw_ncurses_window(rend, dx, dy, dw, dh, flow->box_title);

    char buf[MAX_STR];
    expand_vars(flow->line1, buf, sizeof(buf));
    draw_vga_bold_centered(rend, dx + dw / 2, dy + 42, buf, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);

    expand_vars(flow->line2, buf, sizeof(buf));
    draw_vga_centered(rend, dx + dw / 2, dy + 68, buf, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);

    expand_vars(flow->line3, buf, sizeof(buf));
    draw_vga_centered(rend, dx + dw / 2, dy + 92, buf, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);

    /* Sunken 3D Gauge Bar */
    int gx = dx + 36;
    int gy = dy + 140;
    int gw = dw - 72;
    int gh = 38;
    draw_3d_bevel(rend, gx, gy, gw, gh, 0);

    if (pct > 0) {
        if (pct > 100) pct = 100;
        int max_fill = gw - 8;
        int fill_w = (max_fill * pct) / 100;
        if (fill_w > 0) {
            SDL_SetRenderDrawColor(rend, HL_NAVY_R, HL_NAVY_G, HL_NAVY_B, 255);
            SDL_Rect fill = { gx + 4, gy + 4, fill_w, gh - 8 };
            SDL_RenderFillRect(rend, &fill);
        }
    }

    char pct_str[16];
    snprintf(pct_str, sizeof(pct_str), "%d%%", pct);
    int pct_x = gx + (gw - (int)strlen(pct_str) * 16) / 2;
    int pct_y = gy + (gh - 16) / 2;
    if (pct >= 52) {
        draw_bold_text(rend, pct_x, pct_y, pct_str, FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B);
    } else {
        draw_bold_text(rend, pct_x, pct_y, pct_str, FG_NAVY_R, FG_NAVY_G, FG_NAVY_B);
    }

    if (status_str && status_str[0]) {
        char status_exp[MAX_STR];
        expand_vars(status_str, status_exp, sizeof(status_exp));
        draw_vga_bold_centered(rend, dx + dw / 2, dy + 206, status_exp, FG_NAVY_R, FG_NAVY_G, FG_NAVY_B);
    }

    SDL_RenderPresent(rend);
}

static void animate_flow_progress(SDL_Renderer *rend, ProgressFlow *flow, int from_pct, int to_pct, int duration_ms, const char *status) {
    int steps = duration_ms / 16;
    if (steps < 1) steps = 1;
    for (int s = 1; s <= steps; s++) {
        int cur = from_pct + ((to_pct - from_pct) * s) / steps;
        render_progress_flow(rend, flow, cur, status);
        SDL_Delay(16);
    }
}

static int execute_progress_flow(SDL_Renderer *rend, ProgressFlow *flow) {
    int cur_pct = 0;
    int all_ok = 1;

    for (int i = 0; i < flow->num_steps; i++) {
        ProgressStep *st = &flow->steps[i];
        int next_pct = st->target_pct;
        if (next_pct < cur_pct) next_pct = cur_pct;
        if (next_pct > 100) next_pct = 100;

        animate_flow_progress(rend, flow, cur_pct, next_pct, 280, st->status);
        if (st->cmd[0] != '\0') {
            int rc = system(st->cmd);
            if (rc != 0) {
                all_ok = 0;
            }
        }
        cur_pct = next_pct;
    }

    if (cur_pct < 100) {
        animate_flow_progress(rend, flow, cur_pct, 100, 200, "Done");
    }
    SDL_Delay(200);
    return all_ok;
}

/* Render Completion Screen (`dialog --msgbox`) */
static void render_completion_flow(SDL_Renderer *rend, ProgressFlow *flow, int ok_status) {
    int dx = 44, dy = 68, dw = 540, dh = 330;
    const char *title = ok_status ? flow->complete_title : "Setup Error";
    draw_ncurses_window(rend, dx, dy, dw, dh, title);

    int sx = dx + 26;
    int sy = dy + 42;
    int sw = dw - 52;
    int sh = 192;
    draw_3d_bevel(rend, sx, sy, sw, sh, 0);

    char buf[MAX_STR];
    if (ok_status) {
        int start_y = sy + 22;
        for (int i = 0; i < flow->num_complete_lines; i++) {
            expand_vars(flow->complete_lines[i], buf, sizeof(buf));
            draw_vga_bold(rend, sx + 18, start_y + (i * 34), buf, FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);
        }
    } else {
        draw_vga_bold(rend, sx + 18, sy + 30, "One or more installation commands failed.", FG_BLACK_R, FG_BLACK_G, FG_BLACK_B);
    }

    /* 3D Horizontal Divider above < OK > */
    int div_y = dy + 254;
    SDL_SetRenderDrawColor(rend, DLG_DARK_R, DLG_DARK_G, DLG_DARK_B, 255);
    SDL_Rect div_top = { dx + 10, div_y, dw - 20, 2 };
    SDL_RenderFillRect(rend, &div_top);
    SDL_SetRenderDrawColor(rend, DLG_LIGHT_R, DLG_LIGHT_G, DLG_LIGHT_B, 255);
    SDL_Rect div_bot = { dx + 10, div_y + 2, dw - 20, 2 };
    SDL_RenderFillRect(rend, &div_bot);

    draw_ncurses_button(rend, dx + (dw - 136) / 2, dy + 270, 136, 38, "OK", 1, 0);
    SDL_RenderPresent(rend);
}

static int find_page_by_id(const char *id) {
    for (int i = 0; i < g_cfg.num_pages; i++) {
        if (strcmp(g_cfg.pages[i].id, id) == 0) return i;
    }
    return -1;
}

static ProgressFlow *find_flow_by_id(const char *id) {
    for (int i = 0; i < g_cfg.num_progress; i++) {
        if (strcmp(g_cfg.flows[i].id, id) == 0) return &g_cfg.flows[i];
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    FILE *cfg_fp = stdin;
    if (argc > 1 && strcmp(argv[1], "-") != 0) {
        cfg_fp = fopen(argv[1], "r");
        if (!cfg_fp) {
            fprintf(stderr, "Cannot open config file: %s\n", argv[1]);
            return 1;
        }
    }

    parse_config_stream(cfg_fp);
    if (cfg_fp != stdin) fclose(cfg_fp);

    if (g_cfg.num_pages == 0 && g_cfg.num_progress == 0) {
        fprintf(stderr, "No [page] or [progress] sections found in config.\n");
        return 1;
    }

    open_evdev_inputs();

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) < 0) {
        fprintf(stderr, "SDL_Init error: %s\n", SDL_GetError());
        close_evdev_inputs();
        return 1;
    }

    SDL_Joystick *joy = NULL;
    if (SDL_NumJoysticks() > 0) {
        joy = SDL_JoystickOpen(0);
    }

    SDL_Window *win = SDL_CreateWindow("playOS Setup",
                                       SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                       SCREEN_W, SCREEN_H,
                                       SDL_WINDOW_SHOWN | SDL_WINDOW_FULLSCREEN);
    if (!win) {
        if (joy) SDL_JoystickClose(joy);
        SDL_Quit();
        close_evdev_inputs();
        return 1;
    }

    SDL_Renderer *rend = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!rend) {
        rend = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
    }

    SDL_Delay(200);
    drain_all_inputs();

    /* Multi-Page Wizard Navigation Loop */
    int page_history[MAX_PAGES];
    int history_top = 0;
    int cur_page_idx = 0;
    int action_idx = 0; /* 0 = OK, 1 = Back, 2 = Exit */
    ProgressFlow *selected_flow = NULL;
    int quit_requested = 0;

    if (g_cfg.num_pages == 0 && g_cfg.num_progress > 0) {
        selected_flow = &g_cfg.flows[0];
    }

    while (cur_page_idx >= 0 && cur_page_idx < g_cfg.num_pages && !selected_flow && !quit_requested) {
        WizardPage *page = &g_cfg.pages[cur_page_idx];
        int can_go_back = (history_top > 0);

        if (page->selected_idx < 0 || page->selected_idx >= page->num_options) {
            page->selected_idx = 0;
        }
        if (!can_go_back && action_idx == 1) {
            action_idx = 0;
        }

        render_wizard_page(rend, page, action_idx, can_go_back);
        InputAction act = poll_user_action();

        if (act == ACT_UP && page->num_options > 0) {
            page->selected_idx = (page->selected_idx - 1 + page->num_options) % page->num_options;
        } else if (act == ACT_DOWN && page->num_options > 0) {
            page->selected_idx = (page->selected_idx + 1) % page->num_options;
        } else if (act == ACT_LEFT) {
            if (can_go_back) {
                action_idx = (action_idx - 1 + 3) % 3;
            } else {
                action_idx = (action_idx == 0) ? 2 : 0; /* Toggle between OK (0) and Exit (2) */
            }
        } else if (act == ACT_RIGHT) {
            if (can_go_back) {
                action_idx = (action_idx + 1) % 3;
            } else {
                action_idx = (action_idx == 0) ? 2 : 0; /* Toggle between OK (0) and Exit (2) */
            }
        } else if (act == ACT_TRIGGER) {
            if (action_idx == 2) {
                /* < Exit > triggered */
                quit_requested = 1;
            } else if (action_idx == 1 && can_go_back) {
                /* < Back > triggered */
                cur_page_idx = page_history[--history_top];
                action_idx = 0;
                SDL_Delay(120);
                drain_all_inputs();
            } else if (action_idx == 0 && page->num_options > 0) {
                /* < OK > triggered: execute current Option */
                WizardOption *opt = &page->options[page->selected_idx];

                if (page->var[0] != '\0') {
                    setenv(page->var, opt->value, 1);
                }

                if (strcmp(opt->next_target, "quit") == 0) {
                    quit_requested = 1;
                } else if (strncmp(opt->next_target, "run:", 4) == 0) {
                    selected_flow = find_flow_by_id(opt->next_target + 4);
                    if (!selected_flow && g_cfg.num_progress > 0) {
                        selected_flow = &g_cfg.flows[0];
                    }
                } else if (strncmp(opt->next_target, "page:", 5) == 0) {
                    int next_idx = find_page_by_id(opt->next_target + 5);
                    if (next_idx >= 0) {
                        if (history_top < MAX_PAGES) page_history[history_top++] = cur_page_idx;
                        cur_page_idx = next_idx;
                        action_idx = 0;
                    }
                } else { /* "next" */
                    if (cur_page_idx + 1 < g_cfg.num_pages) {
                        if (history_top < MAX_PAGES) page_history[history_top++] = cur_page_idx;
                        cur_page_idx++;
                        action_idx = 0;
                    } else if (g_cfg.num_progress > 0) {
                        selected_flow = &g_cfg.flows[0];
                    } else {
                        break;
                    }
                }

                SDL_Delay(120);
                drain_all_inputs();
            }
        }

        SDL_Delay(16);
    }

    int ok_status = 1;
    if (selected_flow && !quit_requested) {
        ok_status = execute_progress_flow(rend, selected_flow);

        SDL_Delay(150);
        drain_all_inputs();
        while (1) {
            render_completion_flow(rend, selected_flow, ok_status);
            InputAction act = poll_user_action();
            if (act == ACT_TRIGGER) {
                break;
            }
            SDL_Delay(16);
        }
    }

    if (joy) SDL_JoystickClose(joy);
    SDL_DestroyRenderer(rend);
    SDL_DestroyWindow(win);
    SDL_Quit();
    close_evdev_inputs();

    /* Print plain-text summary for playOS Terminal (FindManager) */
    char buf[MAX_STR];
    if (selected_flow && !quit_requested) {
        printf("==========================================================\n");
        expand_vars(selected_flow->complete_title, buf, sizeof(buf));
        printf("  %s\n", buf);
        printf("----------------------------------------------------------\n");
        for (int i = 0; i < selected_flow->num_complete_lines; i++) {
            expand_vars(selected_flow->complete_lines[i], buf, sizeof(buf));
            printf("  %s\n", buf);
        }
        printf("==========================================================\n");
    } else {
        printf("==========================================================\n");
        printf("  [i] Setup exited without making any changes.\n");
        printf("==========================================================\n");
    }

    return quit_requested ? 0 : (ok_status ? 0 : 1);
}
