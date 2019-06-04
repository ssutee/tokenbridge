const Web3 = require('web3')
const { generateNewBlock } = require('../utils')

const homeWeb3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8541'))
const foreignWeb3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8542'))
const account = '0x7FC1442AB55Da569940Eb750AaD2BAA63DA4010E'
const privateKey = '0x460635eb4ac4287de2d2393985e19b4a9f948ac533453a1044ab8d50330b0df9'
homeWeb3.eth.accounts.wallet.add(privateKey)
foreignWeb3.eth.accounts.wallet.add(privateKey)

function main() {
  setTimeout(async () => {
    generateNewBlock(homeWeb3, account)
    generateNewBlock(foreignWeb3, account)
    main()
  }, 5000)
}

main()

process.on('SIGTERM', function () {
  console.log('Finishing sending blocks...')
  process.exit(0);
});
