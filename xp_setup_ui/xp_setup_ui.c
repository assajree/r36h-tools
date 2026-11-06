/*
 * Universal Windows XP Setup Wizard Engine (xp_setup_ui)
 * Target: R36H Handheld Console (playOS / RK3326 ARM64)
 * Rendering: Direct SDL2 KMSDRM (640x480 @ 60FPS)
 *
 * Layout & Interaction Model:
 *   - Top-Left: Header + "============="
 *   - Body: Step Name + "[X] Option 1..N" + 1-line yellow description
 *   - Bottom Action Row: [ OK ]  [ Back ]  [ Exit ]
 *   - Controls:
 *       * D-Pad UP / DOWN    : Select Option ([X])
 *       * D-Pad LEFT / RIGHT : Select Action Button ([OK] / [Back] / [Exit])
 *       * Button A or B      : Execute the highlighted Action Button
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

/* Palette matching the custom Windows XP Setup Blue Mockup */
#define BG_BLUE_R     42
#define BG_BLUE_G     54
#define BG_BLUE_B     206

#define HL_BLUE_R     26
#define HL_BLUE_G     34
#define HL_BLUE_B     145

#define FG_WHITE_R    255
#define FG_WHITE_G    255
#define FG_WHITE_B    255

#define FG_YELLOW_R   255
#define FG_YELLOW_G   235
#define FG_YELLOW_B   59

#define FG_DESC_R     255
#define FG_DESC_G     230
#define FG_DESC_B     140

#define FG_MUTED_R    115
#define FG_MUTED_G    128
#define FG_MUTED_B    220

#define BAR_GRAY_R    170
#define BAR_GRAY_G    170
#define BAR_GRAY_B    170

/* Limits for Universal Wizard Config */
#define MAX_PAGES       16
#define MAX_OPTIONS     8
#define MAX_PROGRESS    8
#define MAX_STEPS       16
#define MAX_COMP_LINES  8
#define MAX_STR         160
#define MAX_CMD         1024

typedef struct {
    char value[64];
    char next_target[64]; /* "next", "quit", "page:<id>", "run:<id>" */
    char label[MAX_STR];
    char desc[MAX_STR];
} WizardOption;

typedef struct {
    char id[64];
    char title[MAX_STR];  /* Step Name */
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
} WizardConfig;

static WizardConfig g_cfg;

/* Embedded 8x8 bitmap font for ASCII 32..126 */
static const unsigned char font8x8_basic[96][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, /*   */
    {0x18,0x3c,0x3c,0x18,0x18,0x00,0x18,0x00}, /* ! */
    {0x66,0x66,0x24,0x00,0x00,0x00,0x00,0x00}, /* " */
    {0x6c,0x6c,0xfe,0x6c,0xfe,0x6c,0x6c,0x00}, /* # */
    {0x18,0x3e,0x60,0x3c,0x06,0x7c,0x18,0x00}, /* $ */
    {0x00,0x66,0xa6,0xdc,0x3b,0x65,0x66,0x00}, /* % */
    {0x38,0x6c,0x38,0x76,0xdc,0xcc,0x76,0x00}, /* & */
    {0x18,0x18,0x30,0x00,0x00,0x00,0x00,0x00}, /* ' */
    {0x0c,0x18,0x30,0x30,0x30,0x18,0x0c,0x00}, /* ( */
    {0x30,0x18,0x0c,0x0c,0x0c,0x18,0x30,0x00}, /* ) */
    {0x00,0x66,0x3c,0xff,0x3c,0x66,0x00,0x00}, /* * */
    {0x00,0x18,0x18,0x7e,0x18,0x18,0x00,0x00}, /* + */
    {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30}, /* , */
    {0x00,0x00,0x00,0x7e,0x00,0x00,0x00,0x00}, /* - */
    {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00}, /* . */
    {0x06,0x0c,0x18,0x30,0x60,0xc0,0x80,0x00}, /* / */
    {0x3c,0x66,0xc3,0xc3,0xc3,0x66,0x3c,0x00}, /* 0 */
    {0x18,0x38,0x18,0x18,0x18,0x18,0x7e,0x00}, /* 1 */
    {0x3c,0x66,0x06,0x1c,0x30,0x60,0x7e,0x00}, /* 2 */
    {0x3c,0x66,0x06,0x1c,0x06,0x66,0x3c,0x00}, /* 3 */
    {0x0c,0x1c,0x3c,0x6c,0xfe,0x0c,0x0c,0x00}, /* 4 */
    {0x7e,0x60,0x7c,0x06,0x06,0x66,0x3c,0x00}, /* 5 */
    {0x3c,0x66,0x60,0x7c,0x66,0x66,0x3c,0x00}, /* 6 */
    {0x7e,0x06,0x0c,0x18,0x30,0x30,0x30,0x00}, /* 7 */
    {0x3c,0x66,0x66,0x3c,0x66,0x66,0x3c,0x00}, /* 8 */
    {0x3c,0x66,0x66,0x3e,0x06,0x66,0x3c,0x00}, /* 9 */
    {0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00}, /* : */
    {0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30}, /* ; */
    {0x0c,0x18,0x30,0x60,0x30,0x18,0x0c,0x00}, /* < */
    {0x00,0x00,0x7e,0x00,0x7e,0x00,0x00,0x00}, /* = */
    {0x30,0x18,0x0c,0x06,0x0c,0x18,0x30,0x00}, /* > */
    {0x3c,0x66,0x06,0x0c,0x18,0x00,0x18,0x00}, /* ? */
    {0x3c,0x66,0xdf,0xdd,0xd1,0x60,0x3e,0x00}, /* @ */
    {0x38,0x6c,0xc6,0xc6,0xfe,0xc6,0xc6,0x00}, /* A */
    {0xfc,0x66,0x66,0x7c,0x66,0x66,0xfc,0x00}, /* B */
    {0x3c,0x66,0xc0,0xc0,0xc0,0x66,0x3c,0x00}, /* C */
    {0xf8,0x6c,0x66,0x66,0x66,0x6c,0xf8,0x00}, /* D */
    {0xfe,0x62,0x68,0x78,0x68,0x62,0xfe,0x00}, /* E */
    {0xfe,0x62,0x68,0x78,0x68,0x60,0xf0,0x00}, /* F */
    {0x3c,0x66,0xc0,0xc0,0xce,0x66,0x3e,0x00}, /* G */
    {0xc6,0xc6,0xc6,0xfe,0xc6,0xc6,0xc6,0x00}, /* H */
    {0x3c,0x18,0x18,0x18,0x18,0x18,0x3c,0x00}, /* I */
    {0x1e,0x0c,0x0c,0x0c,0xcc,0xcc,0x78,0x00}, /* J */
    {0xe6,0x66,0x6c,0x78,0x6c,0x66,0xe6,0x00}, /* K */
    {0xf0,0x60,0x60,0x60,0x62,0x66,0xfe,0x00}, /* L */
    {0xc6,0xee,0xfe,0xd6,0xc6,0xc6,0xc6,0x00}, /* M */
    {0xc6,0xe6,0xf6,0xde,0xce,0xc6,0xc6,0x00}, /* N */
    {0x38,0x6c,0xc6,0xc6,0xc6,0x6c,0x38,0x00}, /* O */
    {0xfc,0x66,0x66,0x7c,0x60,0x60,0xf0,0x00}, /* P */
    {0x38,0x6c,0xc6,0xc6,0xda,0x6c,0x3e,0x00}, /* Q */
    {0xfc,0x66,0x66,0x7c,0x6c,0x66,0xe6,0x00}, /* R */
    {0x3c,0x66,0x60,0x3c,0x06,0x66,0x3c,0x00}, /* S */
    {0x7e,0x5a,0x18,0x18,0x18,0x18,0x3c,0x00}, /* T */
    {0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00}, /* U */
    {0xc6,0xc6,0xc6,0xc6,0xc6,0x6c,0x38,0x00}, /* V */
    {0xc6,0xc6,0xc6,0xd6,0xfe,0xee,0xc6,0x00}, /* W */
    {0xc6,0xc6,0x6c,0x38,0x6c,0xc6,0xc6,0x00}, /* X */
    {0x66,0x66,0x66,0x3c,0x18,0x18,0x3c,0x00}, /* Y */
    {0xfe,0xc6,0x8c,0x18,0x32,0x66,0xfe,0x00}, /* Z */
    {0x3c,0x30,0x30,0x30,0x30,0x30,0x3c,0x00}, /* [ */
    {0xc0,0x60,0x30,0x18,0x0c,0x06,0x02,0x00}, /* \ */
    {0x3c,0x0c,0x0c,0x0c,0x0c,0x0c,0x3c,0x00}, /* ] */
    {0x10,0x38,0x6c,0xc6,0x00,0x00,0x00,0x00}, /* ^ */
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff}, /* _ */
    {0x30,0x18,0x0c,0x00,0x00,0x00,0x00,0x00}, /* ` */
    {0x00,0x00,0x78,0x0c,0x7c,0xcc,0x76,0x00}, /* a */
    {0xe0,0x60,0x7c,0x66,0x66,0x66,0xdc,0x00}, /* b */
    {0x00,0x00,0x3c,0x66,0x60,0x66,0x3c,0x00}, /* c */
    {0x1c,0x0c,0x7c,0xcc,0xcc,0xcc,0x76,0x00}, /* d */
    {0x00,0x00,0x3c,0x66,0xfe,0x60,0x3c,0x00}, /* e */
    {0x1c,0x36,0x30,0x78,0x30,0x30,0x78,0x00}, /* f */
    {0x00,0x00,0x3e,0x66,0x66,0x3e,0x06,0x7c}, /* g */
    {0xe0,0x60,0x6c,0x76,0x66,0x66,0xe6,0x00}, /* h */
    {0x18,0x00,0x38,0x18,0x18,0x18,0x3c,0x00}, /* i */
    {0x06,0x00,0x06,0x06,0x06,0x66,0x3c,0x00}, /* j */
    {0xe0,0x60,0x66,0x6c,0x78,0x6c,0xe6,0x00}, /* k */
    {0x38,0x18,0x18,0x18,0x18,0x18,0x3c,0x00}, /* l */
    {0x00,0x00,0xec,0xfe,0xd6,0xc6,0xc6,0x00}, /* m */
    {0x00,0x00,0xdc,0x66,0x66,0x66,0x66,0x00}, /* n */
    {0x00,0x00,0x3c,0x66,0x66,0x66,0x3c,0x00}, /* o */
    {0x00,0x00,0xdc,0x66,0x66,0x7c,0x60,0xf0}, /* p */
    {0x00,0x00,0x76,0xcc,0xcc,0x7c,0x0c,0x1e}, /* q */
    {0x00,0x00,0xdc,0x76,0x60,0x60,0xf0,0x00}, /* r */
    {0x00,0x00,0x3c,0x60,0x3c,0x06,0x7c,0x00}, /* s */
    {0x30,0x30,0x7c,0x30,0x30,0x34,0x18,0x00}, /* t */
    {0x00,0x00,0xcc,0xcc,0xcc,0xcc,0x76,0x00}, /* u */
    {0x00,0x00,0xc6,0xc6,0xc6,0x6c,0x38,0x00}, /* v */
    {0x00,0x00,0xc6,0xc6,0xd6,0xfe,0x6c,0x00}, /* w */
    {0x00,0x00,0xc6,0x6c,0x38,0x6c,0xc6,0x00}, /* x */
    {0x00,0x00,0xc6,0xc6,0x66,0x3e,0x06,0x7c}, /* y */
    {0x00,0x00,0x7e,0x4c,0x18,0x32,0x7e,0x00}, /* z */
    {0x0e,0x18,0x18,0x70,0x18,0x18,0x0e,0x00}, /* { */
    {0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00}, /* | */
    {0x70,0x18,0x18,0x0e,0x18,0x18,0x70,0x00}, /* } */
    {0x76,0xdc,0x00,0x00,0x00,0x00,0x00,0x00}  /* ~ */
};

/* String trim & variable expansion helpers */
static char *trim_ws(char *s) {
    while (*s && isspace((unsigned char)*s)) s++;
    if (*s == 0) return s;
    char *end = s + strlen(s) - 1;
    while (end > s && isspace((unsigned char)*end)) {
        *end = '\0';
        end--;
    }
    return s;
}

static void safe_copy(char *dst, const char *src, size_t dst_size) {
    if (!dst || dst_size == 0) return;
    if (!src) {
        dst[0] = '\0';
        return;
    }
    snprintf(dst, dst_size, "%s", src);
}

static void expand_vars(const char *src, char *dst, size_t dst_size) {
    if (!dst || dst_size == 0) return;
    size_t out_i = 0;
    const char *p = src;

    while (*p && out_i + 1 < dst_size) {
        if (*p == '$') {
            p++;
            char var_name[64];
            size_t v_i = 0;
            int braced = 0;
            if (*p == '{') {
                braced = 1;
                p++;
            }
            while (*p && (isalnum((unsigned char)*p) || *p == '_') && v_i + 1 < sizeof(var_name)) {
                var_name[v_i++] = *p++;
            }
            var_name[v_i] = '\0';
            if (braced && *p == '}') p++;

            if (v_i > 0) {
                const char *val = getenv(var_name);
                if (val) {
                    while (*val && out_i + 1 < dst_size) {
                        dst[out_i++] = *val++;
                    }
                }
            } else {
                dst[out_i++] = '$';
            }
        } else {
            dst[out_i++] = *p++;
        }
    }
    dst[out_i] = '\0';
}

static int split_pipe_fields(char *line, char **fields, int max_fields) {
    int count = 0;
    char *cur = line;
    while (cur && count < max_fields) {
        char *sep = strchr(cur, '|');
        if (sep && count < max_fields - 1) {
            *sep = '\0';
            fields[count++] = trim_ws(cur);
            cur = sep + 1;
        } else {
            fields[count++] = trim_ws(cur);
            break;
        }
    }
    return count;
}

static void parse_config_stream(FILE *fp) {
    memset(&g_cfg, 0, sizeof(g_cfg));
    safe_copy(g_cfg.header, "Windows XP Setup", sizeof(g_cfg.header));

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
                safe_copy(cur_flow->box_title, "Setup is copying files...", sizeof(cur_flow->box_title));
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

/* Drawing primitives */
static void draw_char(SDL_Renderer *rend, int x, int y, char c, int scale_x, int scale_y) {
    if (c < 32 || c > 126) c = ' ';
    const unsigned char *glyph = font8x8_basic[c - 32];
    for (int row = 0; row < 8; row++) {
        unsigned char bits = glyph[row];
        for (int col = 0; col < 8; col++) {
            if (bits & (0x80 >> col)) {
                SDL_Rect r = { x + col * scale_x, y + row * scale_y, scale_x, scale_y };
                SDL_RenderFillRect(rend, &r);
            }
        }
    }
}

/* Bold 16x16 text (scale_x=2, scale_y=2) matching the clean mockup */
static void draw_bold_text(SDL_Renderer *rend, int x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    SDL_SetRenderDrawColor(rend, r, g, b, 255);
    int cur_x = x;
    while (*str) {
        draw_char(rend, cur_x, y, *str, 2, 2);
        cur_x += 16;
        str++;
    }
}

/* Compact 8x16 VGA text (scale_x=1, scale_y=2) for descriptions & progress screen */
static void draw_vga_text(SDL_Renderer *rend, int x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    SDL_SetRenderDrawColor(rend, r, g, b, 255);
    int cur_x = x;
    while (*str) {
        draw_char(rend, cur_x, y, *str, 1, 2);
        cur_x += 8;
        str++;
    }
}

static void draw_vga_centered(SDL_Renderer *rend, int center_x, int y, const char *str, Uint8 r, Uint8 g, Uint8 b) {
    int w = (int)strlen(str) * 8;
    draw_vga_text(rend, center_x - (w / 2), y, str, r, g, b);
}

static void draw_thick_rect(SDL_Renderer *rend, int x, int y, int w, int h, int thickness, Uint8 r, Uint8 g, Uint8 b) {
    SDL_SetRenderDrawColor(rend, r, g, b, 255);
    for (int t = 0; t < thickness; t++) {
        SDL_Rect rect = { x + t, y + t, w - 2 * t, h - 2 * t };
        SDL_RenderDrawRect(rend, &rect);
    }
}

static void draw_double_box(SDL_Renderer *rend, int x, int y, int w, int h) {
    SDL_SetRenderDrawColor(rend, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B, 255);
    SDL_Rect outer = { x, y, w, h };
    SDL_Rect inner = { x + 3, y + 3, w - 6, h - 6 };
    SDL_RenderDrawRect(rend, &outer);
    SDL_RenderDrawRect(rend, &inner);
}

/* Draw Top-Left Header + "=============" matching the mockup */
static void draw_mockup_header(SDL_Renderer *rend) {
    char hdr_exp[MAX_STR];
    expand_vars(g_cfg.header, hdr_exp, sizeof(hdr_exp));

    SDL_SetRenderDrawColor(rend, BG_BLUE_R, BG_BLUE_G, BG_BLUE_B, 255);
    SDL_RenderClear(rend);

    draw_bold_text(rend, 48, 36, hdr_exp, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    /* Draw "=============" under Header */
    int eq_count = (int)strlen(hdr_exp);
    if (eq_count < 13) eq_count = 13;
    if (eq_count > 34) eq_count = 34;
    char eq_bar[40];
    for (int i = 0; i < eq_count; i++) eq_bar[i] = '=';
    eq_bar[eq_count] = '\0';
    draw_bold_text(rend, 48, 66, eq_bar, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
}

/* Draw an Action Button ([ OK ], [ Back ], [ Exit ]) */
static void draw_action_button(SDL_Renderer *rend, int x, int y, int w, int h, const char *label, int is_focused, int is_disabled) {
    int text_w = (int)strlen(label) * 16;
    int text_x = x + (w - text_w) / 2;
    int text_y = y + (h - 16) / 2;

    if (is_disabled) {
        draw_thick_rect(rend, x, y, w, h, 2, FG_MUTED_R, FG_MUTED_G, FG_MUTED_B);
        draw_bold_text(rend, text_x, text_y, label, FG_MUTED_R, FG_MUTED_G, FG_MUTED_B);
    } else if (is_focused) {
        /* Focused Button: Solid White Fill + Deep Blue Text */
        SDL_SetRenderDrawColor(rend, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B, 255);
        SDL_Rect fill = { x, y, w, h };
        SDL_RenderFillRect(rend, &fill);
        draw_bold_text(rend, text_x, text_y, label, BG_BLUE_R, BG_BLUE_G, BG_BLUE_B);
    } else {
        /* Unfocused Button: 2px White Outline + White Text */
        draw_thick_rect(rend, x, y, w, h, 2, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
        draw_bold_text(rend, text_x, text_y, label, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
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

/* Render Wizard Page matching the user's mockup */
static void render_wizard_page(SDL_Renderer *rend, WizardPage *page, int action_idx, int can_go_back) {
    draw_mockup_header(rend);

    char buf[MAX_STR];
    expand_vars(page->title, buf, sizeof(buf));
    draw_bold_text(rend, 48, 118, buf, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    int n = page->num_options;
    int start_y = 164;
    int row_step = 38;

    for (int i = 0; i < n; i++) {
        int y = start_y + (i * row_step);
        char opt_label[MAX_STR];
        expand_vars(page->options[i].label, opt_label, sizeof(opt_label));

        char full_line[MAX_STR + 8];
        if (i == page->selected_idx) {
            /* Highlight bar behind selected option + [X] marker */
            int bar_w = ((int)strlen(opt_label) + 4) * 16 + 20;
            if (bar_w < 340) bar_w = 340;
            if (bar_w > 544) bar_w = 544;

            SDL_SetRenderDrawColor(rend, HL_BLUE_R, HL_BLUE_G, HL_BLUE_B, 255);
            SDL_Rect hl = { 42, y - 6, bar_w, 28 };
            SDL_RenderFillRect(rend, &hl);

            SDL_SetRenderDrawColor(rend, FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B, 255);
            SDL_Rect accent = { 42, y - 6, 4, 28 };
            SDL_RenderFillRect(rend, &accent);

            snprintf(full_line, sizeof(full_line), "[X] %s", opt_label);
            draw_bold_text(rend, 52, y, full_line, FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B);
        } else {
            snprintf(full_line, sizeof(full_line), "[ ] %s", opt_label);
            draw_bold_text(rend, 52, y, full_line, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
        }
    }

    /* 1-line soft yellow description before the buttons */
    if (n > 0 && page->options[page->selected_idx].desc[0] != '\0') {
        expand_vars(page->options[page->selected_idx].desc, buf, sizeof(buf));
        draw_vga_text(rend, 48, 344, buf, FG_DESC_R, FG_DESC_G, FG_DESC_B);
    }

    /* Bottom Action Buttons: [ OK ]  [ Back ]  [ Exit ] */
    int btn_y = 392;
    int btn_h = 46;
    draw_action_button(rend, 48,  btn_y, 110, btn_h, "OK",   action_idx == 0, 0);
    draw_action_button(rend, 180, btn_y, 120, btn_h, "Back", action_idx == 1, !can_go_back);
    draw_action_button(rend, 322, btn_y, 120, btn_h, "Exit", action_idx == 2, 0);

    SDL_RenderPresent(rend);
}

/* Render Progress Bar Screen */
static void render_progress_flow(SDL_Renderer *rend, ProgressFlow *flow, int pct, const char *status_str) {
    draw_mockup_header(rend);

    char buf[MAX_STR];
    expand_vars(flow->line1, buf, sizeof(buf));
    draw_vga_centered(rend, 320, 120, buf, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    expand_vars(flow->line2, buf, sizeof(buf));
    draw_vga_centered(rend, 320, 142, buf, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    expand_vars(flow->line3, buf, sizeof(buf));
    draw_vga_centered(rend, 320, 164, buf, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    int bx = 58, by = 224, bw = 524, bh = 96;
    draw_double_box(rend, bx, by, bw, bh);

    expand_vars(flow->box_title, buf, sizeof(buf));
    draw_vga_text(rend, bx + 14, by + 10, buf, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    char pct_str[16];
    snprintf(pct_str, sizeof(pct_str), "%d%%", pct);
    draw_vga_centered(rend, 320, by + 30, pct_str, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);

    int px = 108, py = by + 54, pw = 424, ph = 26;
    SDL_SetRenderDrawColor(rend, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B, 255);
    SDL_Rect pbox = { px, py, pw, ph };
    SDL_RenderDrawRect(rend, &pbox);

    if (pct > 0) {
        if (pct > 100) pct = 100;
        int max_fill = pw - 8;
        int fill_w = (max_fill * pct) / 100;
        if (fill_w > 0) {
            SDL_SetRenderDrawColor(rend, FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B, 255);
            SDL_Rect fill = { px + 4, py + 4, fill_w, ph - 8 };
            SDL_RenderFillRect(rend, &fill);
        }
    }

    /* Bottom Gray Status Bar during copying */
    SDL_SetRenderDrawColor(rend, BAR_GRAY_R, BAR_GRAY_G, BAR_GRAY_B, 255);
    SDL_Rect bar = { 0, 454, SCREEN_W, 26 };
    SDL_RenderFillRect(rend, &bar);

    if (status_str && status_str[0]) {
        char status_exp[MAX_STR];
        expand_vars(status_str, status_exp, sizeof(status_exp));
        int div_x = 410;
        SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
        SDL_Rect vline = { div_x, 454, 2, 26 };
        SDL_RenderFillRect(rend, &vline);
        draw_vga_text(rend, div_x + 6, 459, status_exp, 0, 0, 0);
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

/* Render Completion Screen matching the clean layout + [ OK ] button */
static void render_completion_flow(SDL_Renderer *rend, ProgressFlow *flow, int ok_status) {
    draw_mockup_header(rend);

    char buf[MAX_STR];
    if (ok_status) {
        expand_vars(flow->complete_title, buf, sizeof(buf));
        draw_bold_text(rend, 48, 118, buf, FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B);

        int start_y = 172;
        for (int i = 0; i < flow->num_complete_lines; i++) {
            expand_vars(flow->complete_lines[i], buf, sizeof(buf));
            draw_vga_text(rend, 48, start_y + (i * 32), buf, FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
        }
    } else {
        draw_bold_text(rend, 48, 118, "Setup Error", FG_YELLOW_R, FG_YELLOW_G, FG_YELLOW_B);
        draw_vga_text(rend, 48, 172, "One or more installation commands failed.", FG_WHITE_R, FG_WHITE_G, FG_WHITE_B);
    }

    draw_action_button(rend, 48, 392, 110, 46, "OK", 1, 0);
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

    SDL_Window *win = SDL_CreateWindow("Windows XP Setup",
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
                /* [ Exit ] triggered */
                quit_requested = 1;
            } else if (action_idx == 1 && can_go_back) {
                /* [ Back ] triggered */
                cur_page_idx = page_history[--history_top];
                action_idx = 0;
                SDL_Delay(120);
                drain_all_inputs();
            } else if (action_idx == 0 && page->num_options > 0) {
                /* [ OK ] triggered: execute current Option */
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
