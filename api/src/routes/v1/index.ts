import { Router } from 'express';
import mpesaGroup from './mpesaGroup';
import teamGroup from './teamGroup';

const router: Router = Router();

router.use('/mpesa', mpesaGroup);
router.use('/teams', teamGroup);

export default router;
