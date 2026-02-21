module.exports = {
  format: 'group',

  // exclude `packageManager` dependencies
  dep: ['prod', 'dev', 'optional'],

  filterResults: (pkgName, meta) => {
    const { currentVersionSemver, upgradedVersionSemver } = meta

    // skip if no change in version
    if (currentVersionSemver.toString() === upgradedVersionSemver.toString()) {
      return false
    }

    console.info(
      `${pkgName.padEnd(40)} ${currentVersionSemver.toString().padStart(15)} → ${upgradedVersionSemver}`,
    )

    switch (pkgName) {
      /**
       *
       * case 'pkg-name': {
       *   if (upgradedVersionSemver.toString() === '1.0.0') {
       *     return false
       *   }
       * }
       *
       */

      default: {
        return true
      }
    }
  },
}
