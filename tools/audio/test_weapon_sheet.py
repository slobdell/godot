"""Round 17 G1: the weapon sheet's measurements, each checked against a signal whose answer is known."""

import sys
import unittest
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import weapon_sheet  # noqa: E402

RATE = 44100


def sine(hz, seconds, amplitude=1.0, rate=RATE):
    t = np.arange(int(seconds * rate)) / rate
    return amplitude * np.sin(2 * np.pi * hz * t)


class LoudnessTest(unittest.TestCase):
    def test_a_full_scale_1k_sine_reads_minus_3_lufs(self):
        # BS.1770's own calibration: a 0 dBFS 997 Hz sine in one channel reads -3.01 LUFS.
        x = sine(997, 5.0)[:, None]
        self.assertAlmostEqual(weapon_sheet.integrated_lufs(x, RATE), -3.01, delta=0.1)

    def test_twenty_db_down_is_twenty_lu_down(self):
        x = sine(997, 5.0, 0.1)[:, None]
        self.assertAlmostEqual(weapon_sheet.integrated_lufs(x, RATE), -23.01, delta=0.1)

    def test_k_weighting_discounts_the_sub(self):
        # The K filter's high-pass: a 30 Hz sine at full scale reads well under the 1 kHz one.
        low = weapon_sheet.integrated_lufs(sine(30, 5.0)[:, None], RATE)
        self.assertLess(low, -3.01 - 3.0)

    def test_a_short_sound_still_has_a_momentary_loudness(self):
        x = sine(997, 0.1)[:, None]
        self.assertGreater(weapon_sheet.momentary_max_lufs(x, RATE), -20.0)

    def test_true_peak_sees_the_peak_between_samples(self):
        # A quarter-rate sine sampled at 45 degrees: every sample is at 0.707, the wave peaks at 1.0.
        n = np.arange(4096)
        x = np.sin(2 * np.pi * n / 4 + np.pi / 4)[:, None]
        self.assertAlmostEqual(20 * np.log10(np.abs(x).max()), -3.0, delta=0.1)
        self.assertGreater(weapon_sheet.true_peak_db(x, RATE), -0.6)


class ShapeTest(unittest.TestCase):
    def test_bands_put_a_sine_in_its_own_band(self):
        shares = weapon_sheet.band_shares(sine(55, 1.0), RATE)
        self.assertGreater(shares["40-80"], 0.95)
        shares = weapon_sheet.band_shares(sine(3000, 1.0), RATE)
        self.assertGreater(shares["2k-6k"], 0.95)
        self.assertAlmostEqual(sum(shares.values()), 1.0, places=6)

    def test_attack_time_of_a_click_and_a_swell(self):
        tone = sine(1000, 1.2)
        click = np.concatenate([np.zeros(4410), np.exp(-np.arange(44100) / 4410.0)]) * tone[:48510]
        swell = np.concatenate([np.linspace(0, 1, 22050), np.ones(4410)]) * tone[:26460]
        self.assertLess(weapon_sheet.attack_ms(click, RATE), 3.0)
        self.assertGreater(weapon_sheet.attack_ms(swell, RATE), 300.0)

    def test_crest_of_a_sine_is_3_db(self):
        self.assertAlmostEqual(weapon_sheet.crest_db(sine(440, 1.0), RATE), 3.01, delta=0.1)

    def test_tail_is_the_time_to_fall_40_db(self):
        # 40 dB of exponential decay at 20 dB a second takes two seconds.
        t = np.arange(int(4 * RATE)) / RATE
        x = sine(150, 4.0) * 10 ** (-20 * t / 20)
        self.assertAlmostEqual(weapon_sheet.tail_s(x, RATE, 40.0), 2.0, delta=0.1)

    def test_crack_reads_a_bright_front_and_not_a_dull_one(self):
        # The same body, with and without a broadband first few milliseconds.
        rng = np.random.default_rng(1)
        body = sine(70, 1.0) * np.exp(-np.arange(RATE) / 8000.0)
        crack = rng.standard_normal(RATE) * np.exp(-np.arange(RATE) / 120.0)
        self.assertGreater(weapon_sheet.crack_db(body + crack, RATE), weapon_sheet.crack_db(body, RATE) + 20.0)

    def test_width_of_mono_is_zero_and_of_decorrelated_noise_is_high(self):
        rng = np.random.default_rng(2)
        mono = np.repeat(rng.standard_normal(RATE)[:, None], 2, axis=1)
        wide = rng.standard_normal((RATE, 2))
        self.assertEqual(weapon_sheet.width(mono[:, :1]), 0.0)
        self.assertLess(weapon_sheet.width(mono), 0.01)
        self.assertGreater(weapon_sheet.width(wide), 0.9)


class SheetTest(unittest.TestCase):
    def test_every_weapon_sound_on_the_sheet_exists(self):
        takes = weapon_sheet.shipped_takes()
        for sound in weapon_sheet.SHEET_SOUNDS:
            self.assertIn(sound, takes, "%s has no shipped take" % sound)
            for path in takes[sound]:
                self.assertTrue(path.exists(), path)


if __name__ == "__main__":
    unittest.main()
