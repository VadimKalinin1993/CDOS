/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Copyright (C) 2026 diskOS contributors */
/* toast.c - transient bottom-of-screen message for completion feedback.
 * ui_toast("Imported 3 playlists") shows a pill on lv_layer_top that auto-dismisses.
 * Non-blocking, non-clickable (doesn't eat touches). Replaces any prior toast. */
#include "i18n.h"
#include "screens.h"
#include "theme.h"

static lv_obj_t   *g_toast;
static lv_timer_t *g_toast_timer;

static void toast_hide_cb(lv_timer_t *t)
{
    if(g_toast){ lv_obj_delete_async(g_toast); g_toast = NULL; }
    if(g_toast_timer){ lv_timer_delete(g_toast_timer); g_toast_timer = NULL; }
}

void ui_toast_dismiss(void)
{
    toast_hide_cb(NULL);
}

int ui_toast_hint(const char *msg)
{
    if(g_toast || !msg) return 0;
    ui_toast(msg);
    return 1;
}

void ui_toast(const char *msg)
{
    if(!msg) return;
    msg = tr(msg);   /* the interface language; text with no entry (a name, a count) shows as given */
    if(g_toast){ lv_obj_delete_async(g_toast); g_toast = NULL; }
    if(g_toast_timer){ lv_timer_delete(g_toast_timer); g_toast_timer = NULL; }

    g_toast = lv_obj_create(lv_layer_top());
    lv_obj_remove_style_all(g_toast);
    lv_obj_set_style_bg_color(g_toast, TC(SURFACE_RAISED), 0);
    lv_obj_set_style_bg_opa(g_toast, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(g_toast, 16, 0);
    lv_obj_set_style_pad_all(g_toast, 12, 0);
    lv_obj_set_size(g_toast, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
    lv_obj_set_style_max_width(g_toast, 230, 0);   /* round-screen: bottom chord is narrow, keep the pill inside it */
    lv_obj_align(g_toast, LV_ALIGN_BOTTOM_MID, 0, -64);  /* raised off the clipped bottom edge into the wider chord */
    lv_obj_clear_flag(g_toast, LV_OBJ_FLAG_CLICKABLE);   /* let touches pass through */
    lv_obj_clear_flag(g_toast, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *l = lv_label_create(g_toast);
    lv_label_set_text(l, msg);
    lv_label_set_long_mode(l, LV_LABEL_LONG_WRAP);
    lv_obj_set_width(l, 204);
    lv_obj_set_style_text_align(l, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_font(l, TF(USER_16), 0);   /* some toasts embed a filename/name: chain (issue #3) */
    lv_obj_set_style_text_color(l, TC(TEXT_PRIMARY), 0);

    g_toast_timer = lv_timer_create(toast_hide_cb, 2200, NULL);
}

/* CDOS: a library scan shows a small pill at the bottom while it runs (spinning icon + files so far), on every screen.
 * Polled by main.c (scan_pill_tick); the completion toast ("Scanned N songs") follows when it ends. */
#include "icons.h"
static lv_obj_t *g_scan_pill, *g_scan_lbl;
static void scan_spin_cb(void *o, int32_t v){ lv_obj_set_style_transform_rotation((lv_obj_t *)o, v, 0); }
void ui_scan_pill(int active, int done){
    if(!active){
        if(g_scan_pill){ lv_obj_delete_async(g_scan_pill); g_scan_pill = NULL; g_scan_lbl = NULL; }
        return;
    }
    if(!g_scan_pill){
        g_scan_pill = lv_obj_create(lv_layer_top());
        lv_obj_remove_style_all(g_scan_pill);
        lv_obj_set_style_bg_color(g_scan_pill, TC(SURFACE_RAISED), 0);
        lv_obj_set_style_bg_opa(g_scan_pill, LV_OPA_COVER, 0);
        lv_obj_set_style_radius(g_scan_pill, LV_RADIUS_CIRCLE, 0);
        lv_obj_set_style_pad_hor(g_scan_pill, 14, 0);
        lv_obj_set_style_pad_ver(g_scan_pill, 7, 0);
        lv_obj_set_style_pad_column(g_scan_pill, 8, 0);
        lv_obj_set_size(g_scan_pill, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
        lv_obj_set_flex_flow(g_scan_pill, LV_FLEX_FLOW_ROW);
        lv_obj_set_flex_align(g_scan_pill, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
        lv_obj_align(g_scan_pill, LV_ALIGN_BOTTOM_MID, 0, -18);   /* below the toasts (-64), inside the bottom chord */
        lv_obj_clear_flag(g_scan_pill, LV_OBJ_FLAG_CLICKABLE | LV_OBJ_FLAG_SCROLLABLE);   /* touches pass through */
        lv_obj_t *ic = lv_label_create(g_scan_pill);
        lv_label_set_text(ic, ICON_REFRESH_CW);
        lv_obj_set_style_text_font(ic, &font_lucide_16, 0);
        lv_obj_set_style_text_color(ic, ui_current_accent(), 0);
        lv_obj_set_size(ic, 16, 16);
        lv_obj_set_style_transform_pivot_x(ic, 8, 0);
        lv_obj_set_style_transform_pivot_y(ic, 8, 0);
        lv_anim_t a; lv_anim_init(&a);
        lv_anim_set_var(&a, ic); lv_anim_set_exec_cb(&a, scan_spin_cb);
        lv_anim_set_values(&a, 0, 3600); lv_anim_set_duration(&a, 1200);
        lv_anim_set_repeat_count(&a, LV_ANIM_REPEAT_INFINITE);
        lv_anim_start(&a);
        g_scan_lbl = lv_label_create(g_scan_pill);
        lv_obj_set_style_text_font(g_scan_lbl, TF(UI_14), 0);
        lv_obj_set_style_text_color(g_scan_lbl, TC(TEXT_PRIMARY), 0);
    }
    char b[48];
    if(done > 0) snprintf(b, sizeof b, "%s  %d", tr("Scanning library"), done);
    else snprintf(b, sizeof b, "%s", tr("Scanning library"));
    lv_label_set_text(g_scan_lbl, b);
}
