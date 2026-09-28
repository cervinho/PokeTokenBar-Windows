from __future__ import annotations

import os
import tempfile
import unittest
from unittest.mock import Mock, patch
from datetime import datetime, timedelta, timezone
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QObject, QSettings, Qt
from PySide6.QtGui import QAccessible, QFont, QFontDatabase
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication, QWidget

from poketokenbar_windows.models import (
    LimitWindow,
    ProviderLimits,
    ProviderUsage,
    RateLimitResetCredit,
    UsageSnapshot,
)
from poketokenbar_windows.qml_ui import QmlMainWindow
from poketokenbar_windows.state import CatchRecord, GameState, MonState
from poketokenbar_windows.ui import RefreshResult
from poketokenbar_windows.updates import UpdateState


class LocalSprites:
    def localized_name(self, species_id, language="en"):
        return f"Pokemon {species_id}"

    def sprite_path(self, species_id, shiny=False, animated=True):
        return None

    def egg_sprite_path(self):
        return None


class QmlKeyboardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        # The Windows offscreen plugin does not discover the system fonts.
        # Load the actual UI font so geometry matches an interactive Windows run.
        font = Path(os.environ.get("SystemRoot", "C:/Windows")) / "Fonts" / "segoeui.ttf"
        if font.exists():
            QFontDatabase.addApplicationFont(str(font))
            cls.app.setFont(QFont("Segoe UI", 9))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.settings = QSettings(str(Path(self.tmp.name) / "settings.ini"), QSettings.IniFormat)
        self.settings.setValue("floating_pet/enabled", True)
        self.state = GameState(
            mon=MonState(1, [1, 2, 3], 1, 10, "common", False, "Hardy"),
            used_since_install=10_000_000_000,
            inventory={"rare_candy": 1, "mint": 1, "shiny_charm": 0},
            catches=[
                CatchRecord(
                    i,
                    i,
                    [1, 2, 3] if i == 1 else ([26, 27, 28] if i == 26 else [i]),
                    "common",
                    i == 1,
                    "Hardy",
                    "2026-09-01",
                )
                for i in range(1, 27)
            ],
        )
        self.window = QmlMainWindow(self.state, self.settings, LocalSprites())
        self.addCleanup(self.window.deleteLater)
        self.addCleanup(self.window.hide)
        self.root = self.window.quick.rootObject()
        reset = datetime.now(timezone.utc) + timedelta(hours=2)
        self.window.render(RefreshResult(
            UsageSnapshot(scanned_at=datetime.now(timezone.utc)),
            {"codex": ProviderLimits("codex", plan="Plus", windows=[LimitWindow(f"Window {i}", i * 15, reset) for i in range(5)])},
            {}, self.state, [], None, "Pokemon 2",
        ))
        self.window.show()
        self.window.quick.setFocus()
        QTest.qWait(20)

    def key(self, key, modifiers=Qt.NoModifier):
        QTest.keyClick(self.window.quick, key, modifiers)
        self.app.processEvents()

    def name(self, item):
        accessible = QAccessible.queryAccessibleInterface(item)
        return accessible.text(QAccessible.Text.Name) if accessible else ""

    def description(self, item):
        accessible = QAccessible.queryAccessibleInterface(item)
        return accessible.text(QAccessible.Text.Description) if accessible else ""

    def controls_tree(self, item):
        for child in item.childItems():
            yield child
            yield from self.controls_tree(child)

    def controls(self, item=None):
        for child in (item or self.root).childItems():
            if child.isVisible() and child.isEnabled() and child.activeFocusOnTab():
                yield child
            yield from self.controls(child)

    def control(self, accessible_name):
        return next(item for item in self.controls() if self.name(item) == accessible_name)

    def activate(self, accessible_name):
        self.control(accessible_name).forceActiveFocus(Qt.TabFocusReason)
        self.key(Qt.Key_Space)

    def test_footer_stays_fixed_and_about_contains_full_build_identity(self):
        self.window.resize(520, 640)
        QTest.qWait(20)
        self.assertEqual((self.root.width(), self.root.height()), (520, 640))
        home = self.root.findChild(QObject, "homePage")
        self.assertGreater(home.property("contentHeight"), home.height())
        home.property("contentItem").setProperty("contentY", home.property("contentHeight") - home.height())
        QTest.qWait(20)
        limits = self.root.findChild(QObject, "limitsPanel")
        self.assertLessEqual(limits.mapToItem(home, 0, limits.height()).y(), home.height())
        footer = self.root.findChild(QObject, "shellFooter")
        footer_version = self.root.findChild(QObject, "footerVersion")
        about_version = self.root.findChild(QObject, "aboutBuildVersion")
        settings = self.root.findChild(QObject, "settingsPage")
        self.assertEqual(footer_version.property("text"), self.window.view_model.versionShort)
        self.assertIn(self.window.view_model.buildVersion, about_version.property("text"))
        self.assertNotEqual(footer_version.property("text"), self.window.view_model.buildVersion)
        for page in (0, 1, 4):
            self.root.setProperty("currentPage", page)
            QTest.qWait(20)
            if page == 4:
                content = settings.property("contentItem")
                content.setProperty("contentY", settings.property("contentHeight") - settings.height())
                QTest.qWait(20)
            position = footer.mapToItem(self.root, 0, 0)
            self.assertAlmostEqual(position.y() + footer.height(), self.root.height(), delta=2)

    def test_offline_about_message_and_manual_button_fit_minimum_size(self):
        self.window.resize(520, 640)
        self.root.setProperty("currentPage", 4)
        self.window.view_model.set_update_state(UpdateState("offline"))
        QTest.qWait(30)
        settings = self.root.findChild(QObject, "settingsPage")
        content = settings.property("contentItem")
        content.setProperty("contentY", settings.property("contentHeight") - settings.height())
        QTest.qWait(20)
        about = self.root.findChild(QObject, "aboutSettingsPanel")
        message = self.root.findChild(QObject, "aboutUpdateStatus")
        button = self.root.findChild(QObject, "checkUpdatesButton")
        self.assertTrue(button.isVisible())
        self.assertLessEqual(message.mapToItem(about, 0, 0).y() + message.height(), about.height())
        self.assertLessEqual(button.mapToItem(about, 0, 0).y() + button.height(), about.height())
        self.assertLessEqual(about.mapToItem(self.root, 0, 0).y() + about.height(),
                             settings.mapToItem(self.root, 0, 0).y() + settings.height() + 1)

    def test_about_actions_align_right_without_covering_text(self):
        self.window.resize(520, 640)
        self.root.setProperty("currentPage", 4)
        about = self.root.findChild(QObject, "aboutSettingsPanel")
        version = self.root.findChild(QObject, "aboutBuildVersion")
        message = self.root.findChild(QObject, "aboutUpdateStatus")
        check = self.root.findChild(QObject, "checkUpdatesButton")
        release = self.root.findChild(QObject, "viewReleaseButton")
        for language in ("en", "es", "gl"):
            self.window.view_model.setLanguage(language)
            for state in (UpdateState("no_release"), UpdateState("offline"),
                          UpdateState("available", "v1.1.0",
                                      "https://github.com/pnmartinez/PokeTokenBar-Windows/releases/tag/v1.1.0")):
                self.window.view_model.set_update_state(state)
                QTest.qWait(20)
                text_right = message.mapToItem(about, message.width(), 0).x()
                button_left = check.mapToItem(about, 0, 0).x()
                self.assertLessEqual(text_right + 8, button_left)
                self.assertGreaterEqual(version.mapToItem(about, 0, 0).x(), 10)
                for button in (check, release):
                    if button.isVisible():
                        position = button.mapToItem(about, 0, 0)
                        self.assertLessEqual(position.x() + button.width(), about.width() - 10)
                        self.assertLessEqual(position.y() + button.height(), about.height() - 10)
    def test_backup_buttons_keep_bottom_padding_in_settings(self):
        self.window.resize(520, 640)
        self.root.setProperty("currentPage", 4)
        QTest.qWait(30)
        panel = self.root.findChild(QObject, "appearanceSettingsPanel")
        for name in ("exportBackupButton", "importBackupButton"):
            button = self.root.findChild(QObject, name)
            bottom = button.mapToItem(panel, 0, button.height()).y()
            self.assertGreaterEqual(panel.height() - bottom, 10)
    def test_update_states_and_data_light_are_distinct(self):
        label = self.root.findChild(QObject, "aboutUpdateStatus")
        link = self.root.findChild(QObject, "footerUpdateLink")
        dot = self.root.findChild(QObject, "dataStatusDot")
        self.assertEqual(dot.property("color"), self.root.property("successColor"))
        self.window.view_model.set_update_state(UpdateState("available", "v1.1.0",
            "https://github.com/pnmartinez/PokeTokenBar-Windows/releases/tag/v1.1.0"))
        QTest.qWait(10)
        self.assertIn("v1.1.0", label.property("text"))
        self.assertTrue(link.isVisible())
        self.assertEqual(dot.property("color"), self.root.property("successColor"))
        for state in ("no_release", "offline", "invalid"):
            self.window.view_model.set_update_state(UpdateState(state))
            QTest.qWait(10)
            self.assertFalse(link.isVisible())
            self.assertNotIn("latest Release", label.property("text"))
        self.window.view_model.set_status("Data is stale · refreshing…")
        QTest.qWait(10)
        self.assertEqual(dot.property("color"), self.root.property("warningColor"))
        self.window.view_model.set_status("Update failed · retry scheduled")
        QTest.qWait(10)
        self.assertEqual(dot.property("color"), self.root.property("dangerColor"))
        self.window.view_model.set_status("Updating…")
        QTest.qWait(10)
        self.assertEqual(dot.property("color"), self.root.property("warningColor"))

    def test_tab_and_backtab_keep_every_page_control_named_and_on_screen(self):
        for width in (520, 820):
            for theme in ("light", "dark"):
                self.window.resize(width, 580)
                self.window.view_model.setPreference("theme", theme)
                for page in range(5):
                    with self.subTest(width=width, theme=theme, page=page):
                        self.root.setProperty("currentPage", page)
                        self.root.forceActiveFocus()
                        QTest.qWait(300 if page == 1 else 10)
                        self.window.grab()
                        self.app.processEvents()
                        if page == 1:
                            for _ in range(12):
                                rendered_cards = sum(
                                    self.name(item).startswith("View Pokemon ")
                                    for item in self.controls()
                                )
                                if rendered_cards == len(self.window.view_model.dexEntries):
                                    break
                                QTest.qWait(20)
                                self.window.grab()
                                self.app.processEvents()
                        expected_names = [self.name(item) for item in self.controls()]
                        visited_names = []
                        visited_ids = set()
                        for _ in range(len(expected_names)):
                            self.key(Qt.Key_Tab)
                            item = self.window.quick.quickWindow().activeFocusItem()
                            self.assertIsNotNone(item)
                            self.assertNotIn(id(item), visited_ids, "Tab cycled before reaching every control")
                            visited_ids.add(id(item))
                            name = self.name(item)
                            visited_names.append(name)
                            self.assertTrue(name, item.metaObject().className())
                            point = item.mapToItem(self.root, 0, 0)
                            self.assertGreaterEqual(point.x(), -1)
                            self.assertGreaterEqual(point.y(), -1)
                            self.assertLessEqual(point.x() + item.width(), self.root.width() + 1)
                            self.assertLessEqual(point.y() + item.height(), self.root.height() + 1)
                        self.assertCountEqual(visited_names, expected_names)
                        for _ in range(len(expected_names)):
                            self.key(Qt.Key_Tab, Qt.ShiftModifier)
                            item = self.window.quick.quickWindow().activeFocusItem()
                            point = item.mapToItem(self.root, 0, 0)
                            self.assertGreaterEqual(point.y(), -1)
                            self.assertLessEqual(point.y() + item.height(), self.root.height() + 1)

    def test_restored_settings_respond_to_keyboard_and_persist(self):
        self.root.setProperty("currentPage", 4)
        self.app.processEvents()
        self.activate("Quota percentage: Remaining")
        self.assertEqual(self.settings.value("limit_display_mode"), "remaining")
        self.activate("Reset format: Date")
        self.assertEqual(self.settings.value("limit_time_display_mode"), "datetime")
        warning = self.root.findChild(QObject, "warningThresholdSpin")
        warning.forceActiveFocus(Qt.TabFocusReason)
        self.key(Qt.Key_Up)
        self.assertEqual(self.settings.value("warnThreshold", type=int), 85)
        critical = self.root.findChild(QObject, "criticalThresholdSpin")
        critical.forceActiveFocus(Qt.TabFocusReason)
        self.key(Qt.Key_Down)
        self.assertEqual(self.settings.value("critThreshold", type=int), 90)
        self.activate("Primary limit in tray")
        self.assertFalse(self.settings.value("tray_show_limit", type=bool))
        slider = self.root.findChild(QObject, "petSizeSlider")
        slider.forceActiveFocus(Qt.TabFocusReason)
        previous_size = self.window.view_model.petSize
        self.key(Qt.Key_Right)
        self.assertEqual(self.window.view_model.petSize, previous_size + 8)
        combo = self.root.findChild(QObject, "themeCombo")
        combo.forceActiveFocus(Qt.TabFocusReason)
        self.key(Qt.Key_Down)
        self.assertEqual(self.window.view_model.theme, "light")
        self.assertFalse(self.root.property("darkMode"))

    def test_limits_panel_contains_all_rows_including_more_than_three(self):
        panel = self.root.findChild(QObject, "limitsPanel")
        content = self.root.findChild(QObject, "limitsContent")
        self.assertEqual(len(self.window.view_model.limits), 5)
        self.assertGreaterEqual(panel.height(), 90)
        self.assertEqual(content.property("count"), 5)
        self.assertGreater(content.property("contentHeight"), content.height())

    def test_reset_credit_row_shows_warning_icon(self):
        now = datetime.now(timezone.utc)
        self.window.render(RefreshResult(
            UsageSnapshot(scanned_at=now),
            {
                "codex": ProviderLimits(
                    "codex",
                    reset_credits_available=3,
                    reset_credits=[
                        RateLimitResetCredit(expires_at=now + timedelta(days=2))
                    ],
                )
            },
            {}, self.state, [], None, "Pokemon 2",
        ))
        QTest.qWait(20)
        icon = next(
            (
                item
                for item in self.controls_tree(self.root)
                if item.objectName() == "resetCreditWarningIcon"
            ),
            None,
        )
        self.assertIsNotNone(icon)
        self.assertTrue(icon.property("visible"))
        self.assertEqual(
            icon.property("markColor").name(),
            self.root.property("dangerColor").name(),
        )
        self.window.render(RefreshResult(
            UsageSnapshot(scanned_at=now),
            {
                "codex": ProviderLimits(
                    "codex",
                    windows=[LimitWindow("Weekly", 10, now + timedelta(days=6))],
                    reset_credits_available=3,
                    reset_credits=[
                        RateLimitResetCredit(expires_at=now + timedelta(days=5))
                    ],
                )
            },
            {}, self.state, [], None, "Pokemon 2",
        ))
        QTest.qWait(20)
        warning_icons = [
            item
            for item in self.controls_tree(self.root)
            if item.objectName() == "resetCreditWarningIcon" and item.property("visible")
        ]
        self.assertTrue(warning_icons)
        self.assertEqual(
            warning_icons[0].property("markColor").name(),
            self.root.property("warningColor").name(),
        )
        self.window.render(RefreshResult(
            UsageSnapshot(scanned_at=now),
            {
                "codex": ProviderLimits(
                    "codex",
                    windows=[LimitWindow("Weekly", 10, now + timedelta(days=6))],
                    reset_credits_available=3,
                    reset_credits=[
                        RateLimitResetCredit(expires_at=now + timedelta(days=20))
                    ],
                )
            },
            {}, self.state, [], None, "Pokemon 2",
        ))
        QTest.qWait(20)
        neutral_icons = [
            item
            for item in self.controls_tree(self.root)
            if item.objectName() == "resetCreditWarningIcon"
        ]
        self.assertTrue(neutral_icons)
        self.assertFalse(any(item.property("visible") for item in neutral_icons))

    def test_provider_list_scrolls_only_when_rows_really_overflow(self):
        now = datetime.now(timezone.utc)
        self.window.render(RefreshResult(
            UsageSnapshot(
                providers={
                    "codex": ProviderUsage("codex", today_tokens=10),
                    "cursor": ProviderUsage("cursor", today_tokens=20),
                },
                scanned_at=now,
            ),
            {},
            {},
            self.state,
            [],
            None,
            "Pokemon 2",
        ))
        QTest.qWait(20)
        providers = self.root.findChild(QObject, "providersList")
        self.assertLessEqual(providers.property("contentHeight"), providers.height() + 0.5)
        self.assertFalse(providers.property("interactive"))

        many = {
            f"provider{i}": ProviderUsage(f"provider{i}", today_tokens=i)
            for i in range(1, 6)
        }
        self.window.render(RefreshResult(
            UsageSnapshot(providers=many, scanned_at=now),
            {},
            {},
            self.state,
            [],
            None,
            "Pokemon 2",
        ))
        QTest.qWait(20)
        self.assertGreater(providers.property("contentHeight"), providers.height())
        self.assertTrue(providers.property("interactive"))

    def test_integrated_window_chrome_and_compact_page_layout(self):
        self.assertTrue(self.window.windowFlags() & Qt.WindowType.FramelessWindowHint)
        self.assertIsNotNone(self.root.findChild(QObject, "customTitleBar"))
        for object_name in (
            "minimizeWindowButton",
            "maximizeWindowButton",
            "closeWindowButton",
        ):
            control = self.root.findChild(QObject, object_name)
            self.assertIsNotNone(control)
            self.assertTrue(self.name(control))

        frame = self.root.findChild(QObject, "companionFrame")
        animation = self.root.findChild(QObject, "companionAnimation")
        self.assertAlmostEqual(frame.width(), frame.height(), delta=0.5)
        self.assertGreaterEqual(frame.width(), 136)
        self.assertAlmostEqual(frame.width() - animation.width(), 10, delta=0.5)
        self.assertAlmostEqual(frame.height() - animation.height(), 10, delta=0.5)

        companion_panel = self.root.findChild(QObject, "companionPanel")
        progress = self.root.findChild(QObject, "companionProgressBar")
        progress_position = progress.mapToItem(companion_panel, 0, 0)
        self.assertGreaterEqual(progress_position.y(), 0)
        self.assertLessEqual(progress_position.y() + progress.height(), companion_panel.height())
        refresh = self.root.findChild(QObject, "homeRefreshButton")
        ancestor = refresh.parentItem()
        while ancestor is not None and ancestor is not companion_panel:
            ancestor = ancestor.parentItem()
        self.assertIs(ancestor, companion_panel)

        wallet = self.root.findChild(QObject, "sharedWalletBar")
        self.root.setProperty("currentPage", 2)
        QTest.qWait(20)
        self.window.grab()
        self.app.processEvents()
        bag_y = wallet.mapToItem(self.root, 0, 0).y()
        self.assertTrue(wallet.isVisible())
        self.root.setProperty("currentPage", 3)
        QTest.qWait(20)
        self.window.grab()
        self.app.processEvents()
        self.assertTrue(wallet.isVisible())
        self.assertAlmostEqual(wallet.mapToItem(self.root, 0, 0).y(), bag_y, delta=0.5)
        self.root.setProperty("currentPage", 0)
        QTest.qWait(10)
        self.assertFalse(wallet.isVisible())

    def test_resize_handles_use_qt_edges_and_generous_hit_areas(self):
        expected_edges = {
            "leftResizeHandle": int(Qt.Edge.LeftEdge.value),
            "rightResizeHandle": int(Qt.Edge.RightEdge.value),
            "topResizeHandle": int(Qt.Edge.TopEdge.value),
            "bottomResizeHandle": int(Qt.Edge.BottomEdge.value),
            "topLeftResizeHandle": int((Qt.Edge.TopEdge | Qt.Edge.LeftEdge).value),
            "topRightResizeHandle": int((Qt.Edge.TopEdge | Qt.Edge.RightEdge).value),
            "bottomLeftResizeHandle": int((Qt.Edge.BottomEdge | Qt.Edge.LeftEdge).value),
            "bottomRightResizeHandle": int((Qt.Edge.BottomEdge | Qt.Edge.RightEdge).value),
        }
        for object_name, edges in expected_edges.items():
            with self.subTest(handle=object_name):
                handle = self.root.findChild(QObject, object_name)
                self.assertIsNotNone(handle)
                self.assertEqual(handle.property("resizeEdges"), edges)
                if "Left" in object_name or "Right" in object_name:
                    self.assertGreaterEqual(handle.width(), 12)
                    self.assertGreaterEqual(handle.height(), 12)
                elif object_name in ("leftResizeHandle", "rightResizeHandle"):
                    self.assertGreaterEqual(handle.width(), 8)
                else:
                    self.assertGreaterEqual(handle.height(), 8)

    def test_maximize_glyph_tracks_window_state_in_both_directions(self):
        glyph = self.root.findChild(QObject, "maximizeWindowButtonGlyph")
        self.assertIsNotNone(glyph)
        self.assertEqual(glyph.property("renderedKind"), "maximize")

        def rendered_glyph():
            image = self.window.quick.grabFramebuffer()
            point = glyph.mapToItem(self.root, 0, 0)
            ratio = image.devicePixelRatio()
            return image.copy(
                round(point.x() * ratio), round(point.y() * ratio),
                round(glyph.width() * ratio), round(glyph.height() * ratio),
            )

        maximize_image = rendered_glyph()
        self.window.view_model.toggleMaximizeWindow()
        QTest.qWait(30)
        self.assertTrue(self.window.isMaximized())
        self.assertEqual(glyph.property("renderedKind"), "restore")
        self.assertNotEqual(rendered_glyph(), maximize_image)
        self.window.view_model.toggleMaximizeWindow()
        QTest.qWait(30)
        self.assertFalse(self.window.isMaximized())
        self.assertEqual(glyph.property("renderedKind"), "maximize")

    def test_title_drag_delegates_to_system_even_when_maximized(self):
        handle = Mock()
        handle.startSystemMove.return_value = True
        self.window.showMaximized()
        QTest.qWait(30)
        self.assertTrue(self.window.isMaximized())
        with patch.object(QmlMainWindow, "windowHandle", return_value=handle):
            self.window.view_model.startWindowMove()
        handle.startSystemMove.assert_called_once_with()

    def test_navigation_exposes_page_descriptions_without_page_heading_rows(self):
        labels = [
            "Home",
            "Collection",
            "Bag",
            "Shop",
            "Settings",
        ]
        for label in labels:
            control = self.control(label)
            self.assertTrue(self.description(control), label)
        self.assertIsNotNone(self.root.findChild(QObject, "collectionToolbar"))
        self.root.setProperty("currentPage", 1)
        QTest.qWait(20)
        filter_row = self.root.findChild(QObject, "dexFilterRow")
        page_position = self.root.findChild(QObject, "dexPagePosition")
        page_point = page_position.mapToItem(filter_row, 0, 0)
        self.assertGreaterEqual(page_point.y(), -1)
        self.assertLessEqual(page_point.y() + page_position.height(), filter_row.height() + 1)

    def test_companion_uses_animation_and_reveal_pokeball(self):
        animation = self.root.findChild(QObject, "companionAnimation")
        reveal = self.root.findChild(QObject, "companionReveal")
        self.window.view_model.set_reveal(False)
        QTest.qWait(10)
        self.assertTrue(animation.property("playing"))
        self.assertTrue(animation.isVisible())
        self.window.view_model.set_reveal(True)
        QTest.qWait(10)
        self.assertFalse(animation.isVisible())
        self.assertTrue(reveal.isVisible())

    def test_pokedex_card_opens_animated_detail_and_arrows_cross_pages(self):
        self.root.setProperty("currentPage", 1)
        QTest.qWait(20)
        self.activate("View Pokemon 1")
        self.assertEqual(self.root.property("selectedDexIndex"), 0)
        detail = self.root.findChild(QObject, "dexDetailPanel")
        animation = self.root.findChild(QObject, "dexDetailAnimation")
        self.assertTrue(detail.isVisible())
        self.assertTrue(animation.property("playing"))
        selections = []
        self.window.view_model.representativeChanged.connect(selections.append)
        self.activate("Set as desktop companion")
        self.assertEqual(selections[-1], (1, True))
        self.activate("Next →")
        self.assertEqual(self.root.property("selectedDexIndex"), 1)

        first_page_size = len(self.window.view_model.dexEntries)
        self.root.setProperty("selectedDexIndex", first_page_size - 1)
        self.activate("Next →")
        self.assertEqual(self.root.property("selectedDexIndex"), first_page_size)
        self.activate("Back to Pokédex")
        self.assertEqual(self.root.property("selectedDexIndex"), -1)
        self.assertEqual(self.window.view_model.dexPage, 2)

    def test_back_to_pokedex_keeps_species_after_detail_resize(self):
        self.root.setProperty("currentPage", 1)
        self.window.resize(820, 1000)
        for _ in range(4):
            QTest.qWait(40)
            self.window.grab()
        self.root.openDex(18)
        self.window.resize(520, 640)
        for _ in range(4):
            QTest.qWait(40)
            self.window.grab()
        self.root.closeDex()
        for _ in range(4):
            QTest.qWait(40)
            self.window.grab()
        self.assertIn(
            18, [row["speciesId"] for row in self.window.view_model.dexEntries]
        )
        page = self.root.findChild(QObject, "collectionPage")
        self.assertLessEqual(page.property("contentHeight"), page.property("availableHeight") + 1)
        previous_page = self.window.view_model.dexPage
        self.window.activateWindow()
        self.key(Qt.Key_Right)
        self.assertEqual(self.window.view_model.dexPage, previous_page + 1)

    def test_natures_follow_display_language_without_changing_saved_state(self):
        for language, subtitle, catch_label in (
            ("gl", "Natureza forte", "Forte"),
            ("es", "Naturaleza fuerte", "Fuerte"),
            ("en", "Hardy nature", "Hardy"),
        ):
            self.state.language = language
            self.window.render(RefreshResult(
                UsageSnapshot(scanned_at=datetime.now(timezone.utc)),
                {}, {}, self.state, [], None, "Pokemon 2",
            ))
            self.assertIn(subtitle, self.window.view_model.companionSubtitle)
            self.assertIn(catch_label, self.window.view_model.catches[0]["meta"])
            self.assertEqual(self.state.mon.nature, "Hardy")
            self.assertEqual(self.state.catches[0].nature, "Hardy")

    def test_catch_log_renders_evolution_arrows(self):
        state = GameState(
            mon=MonState(1, [1, 2, 3], 1, 10, "common", False, "Hardy"),
            catches=[
                CatchRecord(
                    1,
                    1,
                    [1, 2, 3],
                    "common",
                    False,
                    "Hardy",
                    "2026-09-01",
                )
            ],
        )
        window = QmlMainWindow(state, self.settings, LocalSprites())
        self.addCleanup(window.deleteLater)
        self.addCleanup(window.hide)
        root = window.quick.rootObject()
        root.setProperty("currentPage", 1)
        root.setProperty("collectionMode", "catches")
        window.show()
        QTest.qWait(50)
        window.grab()
        self.app.processEvents()
        arrows = [
            item
            for item in self.controls_tree(root)
            if item.objectName() == "evolutionArrow"
        ]
        self.assertTrue(any(arrow.isVisible() for arrow in arrows))

    def test_f5_refreshes_only_while_refresh_is_enabled(self):
        self.window.activateWindow()
        QTest.qWait(20)
        requests = []
        def begin_refresh():
            requests.append(True)
            self.window.view_model.set_refresh_enabled(False)

        self.window.refresh_requested.connect(begin_refresh)
        self.root.setProperty("currentPage", 0)
        self.key(Qt.Key_F5)
        self.key(Qt.Key_F5)
        self.assertEqual(len(requests), 1)
        self.assertFalse(self.window.view_model.refreshEnabled)

    def test_tooltips_use_the_panel_focus_and_refresh_hint(self):
        self.window.activateWindow()
        QTest.qWait(20)
        refresh_tip = self.root.findChild(QObject, "refreshTooltip")
        self.assertIn("F5", refresh_tip.property("text"))
        tip = self.root.findChild(QObject, "navigationTooltip-0")
        tip.setProperty("delay", 0)
        tip.setProperty("requestedVisible", True)
        QTest.qWait(20)
        self.assertTrue(self.window.view_model.windowActive)
        self.assertTrue(tip.property("visible"))
        self.assertLess(tip.property("width"), 320)
        refresh_tip.setProperty("delay", 0)
        refresh_tip.setProperty("requestedVisible", True)
        QTest.qWait(20)
        self.assertFalse(tip.property("visible"))
        self.assertTrue(refresh_tip.property("visible"))
        refresh_tip.setProperty("requestedVisible", False)
        tip.setProperty("requestedVisible", False)
        tip.setProperty("requestedVisible", True)
        QTest.qWait(20)
        self.assertTrue(tip.property("visible"))
        other = QWidget()
        self.addCleanup(other.close)
        other.show()
        other.activateWindow()
        QTest.qWait(30)
        self.assertFalse(self.window.view_model.windowActive)
        self.assertFalse(tip.property("visible"))

    def test_mouse_focus_does_not_look_like_keyboard_focus(self):
        self.window.activateWindow()
        home = self.control("Home")
        point = home.mapToItem(self.root, home.width() / 2, home.height() / 2)
        QTest.mouseClick(self.window.quick, Qt.LeftButton, pos=point.toPoint())
        self.assertTrue(home.property("activeFocus"))
        self.assertFalse(home.property("visualFocus"))
        self.key(Qt.Key_Tab)
        collection = self.control("Collection")
        self.assertTrue(collection.property("visualFocus"))

    def test_arrow_keys_navigate_pokedex_page_and_detail(self):
        self.window.activateWindow()
        QTest.qWait(20)
        self.root.setProperty("currentPage", 1)
        self.key(Qt.Key_Right)
        self.assertEqual(self.window.view_model.dexPage, 2)
        self.key(Qt.Key_Left)
        self.assertEqual(self.window.view_model.dexPage, 1)
        self.activate("View Pokemon 1")
        self.key(Qt.Key_Right)
        self.assertEqual(self.root.property("selectedDexIndex"), 1)
        self.key(Qt.Key_Left)
        self.assertEqual(self.root.property("selectedDexIndex"), 0)
        self.root.setProperty("currentPage", 4)
        self.key(Qt.Key_Right)
        self.assertEqual(self.root.property("selectedDexIndex"), 0)

    def test_pokedex_pages_fit_the_visible_grid_after_resize(self):
        self.root.setProperty("currentPage", 1)
        page = self.root.findChild(QObject, "collectionPage")
        grid = self.root.findChild(QObject, "dexGrid")

        def settle_layout():
            for _ in range(4):
                QTest.qWait(40)
                self.window.grab()
                self.app.processEvents()

        self.window.resize(520, 640)
        settle_layout()
        compact_size = len(self.window.view_model.dexEntries)
        self.assertGreater(self.window.view_model.dexPageCount, 1)
        self.assertLessEqual(page.property("contentHeight"), page.property("availableHeight") + 1)
        self.assertEqual(compact_size % grid.property("columns"), 0)

        self.key(Qt.Key_Right)
        anchored_species = self.window.view_model.dexEntries[0]["speciesId"]
        self.window.resize(820, 1000)
        settle_layout()
        self.assertGreater(len(self.window.view_model.dexEntries), compact_size)
        self.assertIn(
            anchored_species,
            [row["speciesId"] for row in self.window.view_model.dexEntries],
        )
        self.assertLessEqual(page.property("contentHeight"), page.property("availableHeight") + 1)

    def test_collection_can_be_paged_and_switched_using_keyboard(self):
        self.root.setProperty("currentPage", 1)
        self.app.processEvents()
        self.activate("Show normal Pokemon 1")
        self.assertFalse(self.window.view_model.dexEntries[0]["showShiny"])
        self.activate("Next →")
        self.assertEqual(self.window.view_model.dexPage, 2)
        self.activate("← Previous")
        self.assertEqual(self.window.view_model.dexPage, 1)
        self.activate("Collection view: Catch log")
        self.assertEqual(self.root.property("collectionMode"), "catches")
        self.activate("Collection view: Pokédex")
        self.assertEqual(self.root.property("collectionMode"), "dex")


if __name__ == "__main__":
    unittest.main()
