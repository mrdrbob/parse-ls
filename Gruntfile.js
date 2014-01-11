module.exports = function(grunt) {

  grunt.loadNpmTasks('grunt-mocha-test');
  grunt.loadNpmTasks('grunt-livescript');

  grunt.initConfig({
    mochaTest: {
      test: {
        options: {
          reporter: 'spec',
          require: 'LiveScript'
        },
        src: ['test/**/*.ls']
      }
    },
    livescript: {
      src: {
        files: {
          'lib/parse.js': 'src/parse.ls'
        }
      }
    }
  });

  grunt.registerTask('default', ['mochaTest', 'livescript']);
  grunt.registerTask('test', 'mochaTest');

};