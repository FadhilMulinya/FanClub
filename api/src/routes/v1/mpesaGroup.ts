import { Router } from 'express'
import { createStkPush, stkCallbackHandler } from '../../controllers/mpesa'

const router: Router = Router()

router.post('/stk/init', createStkPush)
router.post('/stk/callback', stkCallbackHandler)

export default router
