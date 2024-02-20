module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/tests/**/*.test.ts"], // テストファイルのパターンを指定
  testPathIgnorePatterns: ["/node_modules/"], // node_modulesを無視
};
